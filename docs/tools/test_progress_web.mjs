// Execute the shipped bridge expressions and loading-menu hooks with denied,
// missing and working storage. No real browser profile or user save is touched.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const progress = readFileSync(new URL('../../scripts/Progress.gd', import.meta.url), 'utf8');
const expressions = [...progress.matchAll(/JavaScriptBridge\.eval\("((?:\\.|[^"\\])*)"/g)]
  .map(match => JSON.parse('"' + match[1] + '"'));
assert.equal(expressions.length, 2);
const key = 'curfew_progress';
const saved = JSON.stringify({version: 1, unlocked: 2});
const read = expressions[0].replace('%s', key);
const write = expressions[1].replace('%s', key).replace('%s', JSON.stringify(saved));
let checks = 0;
function check(name, action) {
  action();
  checks++;
  console.log(name + '  ok: true');
}
check('missing browser storage reads an empty save', () => {
  assert.equal(vm.runInNewContext(read, {localStorage: {getItem: () => null}}), '');
});
check('a saved browser unlock reads back exactly', () => {
  assert.equal(vm.runInNewContext(read, {localStorage: {getItem: name => name === key ? saved : null}}), saved);
});
check('denied reads return safely instead of throwing', () => {
  assert.equal(vm.runInNewContext(read, {localStorage: {getItem() {throw Error('denied');}}}), '');
});
check('an unavailable localStorage API returns safely', () => {
  assert.equal(vm.runInNewContext(read, {}), '');
});
check('saving writes the progress key and a JSON string', () => {
  const stored = new Map();
  assert.equal(vm.runInNewContext(write, {localStorage: {setItem: (name, text) => stored.set(name, text)}}), true);
  assert.equal(stored.get(key), saved);
  assert.deepEqual(JSON.parse(stored.get(key)), {version: 1, unlocked: 2});
});
check('quota or permission failure reports an unsuccessful save', () => {
  assert.equal(vm.runInNewContext(write, {localStorage: {setItem() {throw Error('quota');}}}), false);
});
check('an unavailable storage API reports an unsuccessful save', () => {
  assert.equal(vm.runInNewContext(write, {}), false);
});

const shell = readFileSync(new URL('../../web/shell.html', import.meta.url), 'utf8');
const menuHook = shell.match(/window\.curfewMenuReady = function \(\) \{[\s\S]*?\n\t\};/)[0];
const holdHook = shell.match(/window\.curfewHold = function \(\) \{[\s\S]*?\n\t\};/)[0];
let removed = 0;
let cleared = 0;
const context = vm.createContext({window: {}, finished: false, holding: true, tipTimer: 1,
  clearTimeout: () => cleared++, boot: {remove: () => removed++}});
vm.runInContext(menuHook + '\n' + holdHook, context);
check('the entry chooser dismisses the loader once without marking a city built', () => {
  context.window.curfewMenuReady();
  context.window.curfewMenuReady();
  assert.equal(context.finished, true);
  assert.equal(context.holding, false);
  assert.equal(removed, 1);
  assert.equal(cleared, 1);
});
check('choosing Continue has no hidden loading-tip hold', () => {
  assert.equal(context.window.curfewHold(), 0);
});
console.log(`${checks} Web storage/loader checks passed`);
