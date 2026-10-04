#!/usr/bin/env python3
"""Snapshot the game and export an isolated browser audit (never publish this build)."""
import argparse
import hashlib
import json
import shutil
import subprocess
import tempfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
GODOT = '/Applications/Godot.app/Contents/MacOS/Godot'
HOOK = '''<script>
const auditNativeMemory = WebAssembly.Memory;
WebAssembly.Memory = function(...args) { const memory = new auditNativeMemory(...args); window.auditWasmMemory = memory; return memory; };
WebAssembly.Memory.prototype = auditNativeMemory.prototype;
const auditNativeInstantiate = WebAssembly.instantiate;
WebAssembly.instantiate = async function(...args) { const result = await auditNativeInstantiate.apply(this,args); const instance = result.instance || result; for (const value of Object.values(instance.exports || {})) if (value instanceof auditNativeMemory) window.auditWasmMemory = value; return result; };
const auditNativeStreaming = WebAssembly.instantiateStreaming;
WebAssembly.instantiateStreaming = async function(...args) { const result = await auditNativeStreaming.apply(this,args); const instance = result.instance || result; for (const value of Object.values(instance.exports || {})) if (value instanceof auditNativeMemory) window.auditWasmMemory = value; return result; };
window.auditLogs=[];
function auditLog(message) { window.auditLogs.push(String(message));window.auditLogs=window.auditLogs.slice(-200);fetch('/audit-result',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({name:'log-'+location.pathname.split('/').at(-2)+'-'+(new URLSearchParams(location.search).get('mode') || 'normal'),messages:window.auditLogs})}).catch(()=>{}); let el=document.getElementById('audit-log'); if(!el){el=document.createElement('pre');el.id='audit-log';el.style='position:fixed;top:0;left:0;z-index:99;background:#222;color:#fff;max-height:40vh;overflow:auto';document.body.append(el);}el.textContent += message+'\\n'; }
window.auditMode = new URLSearchParams(location.search).get('mode') || 'normal';
window.auditNoAudio = window.auditMode === 'no_audio';
window.auditStarted = false;
window.auditPublish = function(report) {
  fetch('/audit-result', {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(report)}).catch(error=>auditLog(String(error)));
  let el=document.getElementById('audit-progress');
  if(!el){el=document.createElement('pre');el.id='audit-progress';el.style='position:fixed;bottom:0;left:0;z-index:100;background:#222;color:#fff;max-width:100vw;white-space:pre-wrap';document.body.append(el);}
  const latest=report.after_idle || report.cleanup || report.samples.at(-1)?.after;
  el.textContent=report.name+' '+(report.complete?'COMPLETE':'running')+' '+report.samples.length+' cycles\\n'+JSON.stringify(latest);
};
document.addEventListener('DOMContentLoaded',()=>{
  const button=document.createElement('button');button.textContent='Start audit';button.id='audit-start';button.style='position:fixed;top:0;right:0;z-index:101;font-size:24px';
  button.onclick=()=>{window.auditStarted=true;button.remove();};document.body.append(button);
});
</script>'''

# Read scalar ownership counts inside the generated engine's closure. Never
# retain AudioBuffers/GL objects in the report itself. Diagnostic exports only.
RUNTIME_HOOK = '''window.auditRuntimeSnapshot=function(){
const a=GodotAudio; const bytes=b=>b?b.length*b.numberOfChannels*4:0;
let registeredBytes=0, playbackBytes=0, busRefs=0;
for(const sample of a.samples?.values() || []) registeredBytes+=bytes(sample._audioBuffer);
for(const node of a.sampleNodes?.values() || []) playbackBytes+=bytes(node._source?.buffer);
for(const bus of a.buses || []) busRefs+=bus._sampleNodes?.size || 0;
return {js_heap_bytes:performance.memory?.usedJSHeapSize ?? -1,
wasm_capacity_bytes:wasmMemory.buffer.byteLength,
audio_samples:a.samples?.size || 0,audio_playbacks:a.sampleNodes?.size || 0,
audio_registered_bytes:registeredBytes,audio_playback_bytes:playbackBytes,
audio_bus_references:busRefs,audio_worklet_pool:a.audioPositionWorkletNodes?.length || 0,
audio_state:a.ctx?.state || 'none',gl_textures:GL.textures.filter(Boolean).length,
gl_buffers:GL.buffers.filter(Boolean).length};};'''

def build(output, probe='performance', playback=None):
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='curfew-audit-web-') as directory:
        target = Path(directory)
        for folder in ['scripts', 'scenes', 'assets']:
            shutil.copytree(ROOT / folder, target / folder, ignore=shutil.ignore_patterns('*.import'))
        shutil.copy2(ROOT / 'default_bus_layout.tres', target / 'default_bus_layout.tres')
        shutil.copy2(ROOT / 'docs/tools/world_helpers.gd', target / 'audit_helpers.gd')
        if probe == 'restarts':
            # Omit playback rather than merely muting; source resources and
            # world construction stay identical for the no_audio comparison.
            for filename, call in [('AudioDirector.gd', 'p.play()'), ('SteamVent.gd', 'hiss.play()')]:
                path = target / 'scripts' / filename
                text = path.read_text().replace(call, 'if not JavaScriptBridge.eval("window.auditNoAudio", true): ' + call)
                path.write_text(text)
        config = (ROOT / 'project.godot').read_text().replace('run/main_scene="res://scenes/Main.tscn"', 'run/main_scene="res://Audit.tscn"')
        if playback is not None:
            # Project setting values are Stream=0, Sample=1. These differ
            # from AudioStreamPlayer's enum, which also includes Default.
            audio_section = '\n[audio]\n\ngeneral/default_playback_type.web=' + str(0 if playback == 'stream' else 1) + '\n'
            if '[audio]' in config:
                import re
                config = re.sub(r'general/default_playback_type\.web=\d+', 'general/default_playback_type.web=' + str(0 if playback == 'stream' else 1), config)
            else:
                config += audio_section
        (target / 'project.godot').write_text(config)
        preset = (ROOT / 'export_presets.cfg').read_text().replace('html/custom_html_shell="res://web/shell.html"', 'html/custom_html_shell=""')
        (target / 'export_presets.cfg').write_text(preset)
        source = (ROOT / 'docs/tools/audit_performance.gd').read_text().replace('extends SceneTree', 'extends Node', 1).replace('res://docs/tools/world_helpers.gd', 'res://audit_helpers.gd')
        source = source.replace('var report :=', 'var root: Window:\n    get: return get_tree().root\nvar process_frame: Signal:\n    get: return get_tree().process_frame\nvar paused: bool:\n    get: return get_tree().paused\n    set(value): get_tree().paused=value\nvar report :=', 1)
        source = source.replace('    return {"static_bytes":OS.get_static_memory_usage()', '    var sample := {"static_bytes":OS.get_static_memory_usage()')
        source = source.replace('\nfunc fresh(level: int):', '\n    sample.wasm_capacity_bytes=JavaScriptBridge.eval("window.auditWasmMemory ? window.auditWasmMemory.buffer.byteLength : -1",true)\n    sample.js_heap_bytes=JavaScriptBridge.eval("performance.memory ? performance.memory.usedJSHeapSize : -1",true)\n    return sample\nfunc fresh(level: int):')
        source = source.replace('"seed":731,"debug":OS.is_debug_build()}', '"home_seed":731,"debug":OS.is_debug_build(),"browser":JavaScriptBridge.eval("navigator.userAgent",true)}')
        hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (target / 'scripts').glob('*.gd')}
        start = source.index('    report.source_hashes={}')
        end = source.index('    report.baseline=snapshot()', start)
        source = source[:start] + '    report.source_hashes=' + json.dumps(hashes) + '\n' + source[end:]
        source = source.replace('    file.store_string(JSON.stringify(report,"  "))', '    if file: file.store_string(JSON.stringify(report,"  "))')
        source = source.replace('    quit()', '''    await get_tree().create_timer(10.0).timeout
    report.after_idle=snapshot()
    var summary := "Browser audit complete\\n" + JSON.stringify(report.environment) + "\\n"
    for row in report.scenarios:
        summary += "%s: median %.2f ms, p95 %.2f ms, max %.2f ms; draw calls %d\\n" % [row.name,row.frame_ms.p50,row.frame_ms.p95,row.frame_ms.max,row.draw_calls.p50]
    summary += "Cleanup cycles: " + JSON.stringify(report.cycles[0]) + " -> " + JSON.stringify(report.cycles[-1])
    var json := JSON.stringify(report,"  ")
    JavaScriptBridge.eval("document.body.innerHTML='<pre id=audit-report></pre><a id=audit-download download=curfew-browser-audit.json>Download audit JSON</a>';document.getElementById('audit-report').textContent="+JSON.stringify(summary)+";document.getElementById('audit-download').href='data:application/json;charset=utf-8,'+encodeURIComponent("+JSON.stringify(json)+");document.body.style='background:#161922;color:#eee;font:16px monospace;padding:24px'")''')
        if probe != 'performance':
            source = (ROOT / f'docs/tools/audit_{probe}.gd').read_text()
            if probe == 'soak':
                shutil.copy2(ROOT / 'docs/tools/audit_restarts.gd', target / 'audit_restarts.gd')
                shutil.copy2(ROOT / 'docs/tools/audit_route.gd', target / 'audit_route.gd')
                source = source.replace('res://docs/tools/audit_restarts.gd', 'res://audit_restarts.gd').replace('res://docs/tools/audit_route.gd', 'res://audit_route.gd')
            source = source.replace('    report.baseline = runtime()', '    report.source_hashes = ' + json.dumps(hashes) + '\n    report.baseline = runtime()')
        (target / 'audit_node.gd').write_text(source)
        (target / 'Audit.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://audit_node.gd" id="1"]\n[node name="Audit" type="Node"]\nscript = ExtResource("1")\n')
        for args in [['--editor', '--import'], ['--export-release', 'Web', str(output / 'index.html')]]:
            result = subprocess.run([GODOT, '--headless', '--path', str(target), *args], capture_output=True, text=True, timeout=120)
            if result.returncode or 'Parse Error' in result.stdout + result.stderr:
                raise RuntimeError(result.stdout + result.stderr)
        page = output / 'index.html'
        html = page.read_text().replace('</head>', HOOK + '\n</head>').replace('engine.startGame({', "engine.startGame({\n'onPrint': auditLog,\n'onPrintError': auditLog,")
        page.write_text(html)
        if probe != 'performance':
            engine = output / 'index.js'
            js = engine.read_text()
            marker = 'var GodotAudioWorklet='
            if js.count(marker) != 1:
                raise RuntimeError('Engine instrumentation marker changed')
            engine.write_text(js.replace(marker, RUNTIME_HOOK + marker, 1))
    print(f'Browser audit exported to {output}; serve the project root and open its index.html.')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', default=str(ROOT / 'build/audit-web'))
    parser.add_argument('--probe', choices=['performance', 'restarts', 'soak'], default='performance')
    parser.add_argument('--playback', choices=['stream', 'sample'])
    args = parser.parse_args()
    build(args.output, args.probe, args.playback)
