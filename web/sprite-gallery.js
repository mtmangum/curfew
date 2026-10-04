'use strict';
const sprites = window.CURFEW_SPRITES;
const sections = [
  ['cast', 'The cast', 'Two companions, one long walk home.', ['player', 'dog']],
  ['hazards', 'Street hazards', 'Patrols, passing skaters, and trouble after curfew.', ['cop', 'skater', 'hobo', 'punk', 'zombie']],
  ['wildlife', 'Wildlife', 'Small distractions with noisy consequences.', ['cat', 'squirrel']],
  ['props', 'Neighbourhood', 'The pixel-art furniture among the procedural city.', ['trashbin', 'trashfire', 'tree']],
  ['rooftops', 'Rooftop objects', 'Rendered from the same Godot drawing code used in the game.', ['rooftopac', 'rooftopwater', 'rooftophouse']],
  ['details', 'Street details', 'Drawn in code by the game rather than as pixel art: the iron at the foot of each tree, and the shopfronts.', ['treegrate', 'shopwindow', 'neonsign']],
  ['signals', 'Signals & clues', 'How the game tells you what is going on: the marks over a cop, Stella\'s nose, and the pictures on the clue cards.', ['copmark', 'thought', 'clueicon']],
];
const info = {
  treegrate: ['Tree grate', 'A square cast-iron grate set in the pavement round every street tree: a steel frame, rings of radial slots and a dark pit for the trunk. 17 units across at the kerb, up to 26 in the plazas, and never on the road. It lies on the ground, so anyone walking past stands over it.', 'planted', 1],
  shopwindow: ['Shop window', 'Seven kinds of shop (shoes, hats, electronics, a boutique, a grocer, a bakery and books), picked by the building. A shop has several windows that differ from each other; in about one shop in three the second carries a neon OPEN sign.', 'shoes', 0.8],
  neonsign: ['Neon OPEN sign', 'A pixel-font sign on a dark board, pink, cyan or red, with a faint halo. Drawn along the wall, so it slants with the building.', 'pink', 1],
  copmark: ['Cop alert marks', 'A yellow ? over a cop going to look at a noise or a glimpse, and a red ! when he is after you. Each pops in large and settles; the ! also throbs.', 'alert', 6],
  thought: ['Stella\'s thought bubble', 'A house in a bubble over her head while she leads Nicole toward home, on every sniff.', 'bubble', 5],
  clueicon: ['Clue pictures', 'The pictures on the card that explains something the first time it happens: a bin, a house, a paw, a zombie and the two cop marks. Clues show once each, on levels 1 to 3 only.', 'bin', 1],
  rooftopac: ['Air-conditioning unit', 'Sheet-metal cabinet with louvres, an access panel, and a rooftop fan. Three cabinet colours; select spin to see the turning fan.', 'spin', 0.7 * 16 / (2 * Math.PI)],
  rooftopwater: ['Water tank', 'Wooden staves, iron hoops, a conical cap, and braced legs. Placed in the back corner of roughly one roof in three.', 'tank', 0],
  rooftophouse: ['House roof & chimney', 'The destination house has a pitched terracotta roof, a brick chimney, and a thread of smoke.', 'roof', 0],
  player: ['Nicole', 'Walks home with Stella. Sneaking slows her stride; the fall pose is a separate asset.', 'walk', 10],
  dog: ['Stella', 'A greyhound on a short leash. Walks, gallops, marks hydrants, and rears to bark up trees.', 'walk', 8],
  cop: ['Cop', 'Walk frames show a calm patrol. The patrol-named frames raise the club for a chase.', 'walk', 6],
  skater: ['Skateboarder', 'Rides through the streets. The bail frame shows the aftermath of a collision.', 'ride', 5],
  hobo: ['Hobo', 'Shuffles and rants in the blackout neighbourhood, from level 2 onward.', 'shuffle', 6],
  punk: ['Punk', 'Walks the streets and shoves Nicole if she gets too close, from level 2 onward.', 'walk', 6],
  zombie: ['Zombie hobo', 'Shambles after Nicole. Sitting and lying poses are used for resting street people.', 'shuffle', 6],
  cat: ['Cat', 'Runs, sits, and hisses. Knocks over bins and tempts Stella into a noisy chase.', 'run', 10],
  squirrel: ['Squirrel', 'Sits, chatters, runs, and climbs. A level 1 distraction that sends Stella barking up a tree.', 'run', 10],
  trashbin: ['Trash bin', 'An isometric metal bin with an oval lid and curved ribs. The game rotates it when a cat knocks it over.', 'upright', 1],
  trashfire: ['Trash fire', 'An open isometric barrel with curved steel hoops and two flame frames. Its glow makes nearby characters easier for cops to spot.', 'flicker', 5],
  tree: ['Trees', 'Four distinct tree variants, not an animation. Select a frame to inspect each silhouette. Each stands in a cast-iron grate (see Street details).', 'tree', 0],
};
const cards = [];
// LevelSettings.gd controls the gated roster; cats and scenery are built on every level.
const firstLevel = {hobo: 2, punk: 2, zombie: 2};
const lastLevel = {squirrel: 1, clueicon: 3};  // gated off after this level
// Drawn in code by the game and rendered here from the same functions (docs/tools/render_gallery_extras.gd,
// render_rooftop_gallery.gd), rather than pixel art from assets/sprites.
const procedural = new Set(['treegrate', 'shopwindow', 'neonsign', 'copmark', 'thought', 'clueicon']);
let playing = !matchMedia('(prefers-reduced-motion: reduce)').matches;
let elapsed = 0;
let previous = null;
const play = document.querySelector('#play');
function updatePlay() {
  play.textContent = playing ? 'Pause animations' : 'Play animations';
  play.setAttribute('aria-pressed', String(playing));
}
updatePlay();
play.addEventListener('click', () => { playing = !playing; updatePlay(); });
const zoom = document.querySelector('#zoom');
const speed = document.querySelector('#speed');
const theme = document.querySelector('#theme');
theme.addEventListener('click', () => {
  const dark = document.documentElement.dataset.theme !== 'dark';
  document.documentElement.dataset.theme = dark ? 'dark' : 'light';
  theme.textContent = dark ? 'Light theme' : 'Dark theme';
});
function framesFor(folder, state) {
  if (folder === 'dog' && state === 'gallop') return [...sprites.dog.extended, ...sprites.dog.gathered];
  return sprites[folder][state];
}
function draw(card, index) {
  const frame = card.frames[index];
  card.index = index;
  if (card.image.getAttribute('src') !== frame.src) card.image.src = frame.src;
  card.image.alt = `${card.name}: ${frame.name}`;
  card.image.style.width = `${frame.width * Number(zoom.value)}px`;
  card.image.style.height = `${frame.height * Number(zoom.value)}px`;
  card.el.querySelector('.stage').style.height = `${Math.max(230, Math.max(...card.frames.map(f => f.height)) * Number(zoom.value) + 70)}px`;
  card.dims.textContent = `${frame.width} × ${frame.height} px`;
  card.meta.textContent = `${frame.name}.png · Frame ${index + 1} / ${card.frames.length}`;
  for (const [i, link] of [...card.links.children].entries()) link.setAttribute('aria-current', String(i === index));
}
function setState(card, state) {
  card.state = state;
  card.fps = card.folder === 'zombie' && ['lie', 'sit'].includes(state) ? 0.7 : info[card.folder][3];
  card.frames = framesFor(card.folder, state);
  card.origin = elapsed;
  card.links.replaceChildren();
  card.frames.forEach((frame, i) => {
    const link = document.createElement('a');
    link.href = frame.src;
    link.target = '_blank';
    link.rel = 'noopener';
    link.textContent = frame.name;
    link.title = `Open original ${frame.width} × ${frame.height} PNG`;
    card.links.append(link);
  });
  draw(card, 0);
}
for (const [id, title, note, folders] of sections) {
  const section = document.createElement('section');
  section.innerHTML = `<h2 id="${id}">${title}</h2><p class="section-note">${note}</p><div class="grid"></div>`;
  document.querySelector('#gallery').append(section);
  for (const folder of folders) {
    if (!sprites[folder]) continue;
    const [name, description, initial, fps] = info[folder];
    const el = document.createElement('article');
    el.className = 'card';
    el.innerHTML = `<div class="stage"><span class="stage-label">${folder === 'tree' ? 'Variants' : 'Animation preview'}</span><span class="dimensions"></span><img alt=""></div><div class="body"><div class="name-row"><h3>${name}</h3><span class="badge">In game</span></div><p class="description">${description}</p><div class="card-controls"><label class="state-label">${folder === 'tree' ? 'Asset group' : 'Animation state'}<select aria-label="${name} animation state"></select></label><button type="button" class="step" aria-label="Next ${name} frame" title="Pause and advance one frame">Step →</button><button type="button" class="flip" aria-label="Flip ${name}" aria-pressed="false">Flip</button></div><p class="frame-meta"></p><div class="frame-links" aria-label="Original PNG frames"></div></div>`;
    section.querySelector('.grid').append(el);
    const level = firstLevel[folder] || 1;
    const appearance = document.createElement('p');
    appearance.className = 'appearance';
    appearance.innerHTML = `<span>First appears</span> <strong>Level ${level}</strong><small>${lastLevel[folder] ? (lastLevel[folder] === level ? `Level ${level} only` : `Levels ${level} to ${lastLevel[folder]} only`) : `Level ${level} and onward`}</small>`;
    el.querySelector('.description').before(appearance);
    if (folder.startsWith('rooftop') || procedural.has(folder)) {
      el.querySelector('.badge').textContent = 'Godot render';
      el.querySelector('.stage-label').textContent = 'Procedural art preview';
    }
    const states = Object.keys(sprites[folder]);
    if (folder === 'dog') {
      states.splice(states.indexOf('extended'), 1);
      states.splice(states.indexOf('gathered'), 1);
      states.push('gallop');
    }
    const select = el.querySelector('select');
    for (const state of states) select.add(new Option(state.replace(/([a-z])([A-Z])/g, '$1 $2'), state));
    select.value = initial;
    const card = {el, section, folder, name, fps, select, image: el.querySelector('img'), dims: el.querySelector('.dimensions'), meta: el.querySelector('.frame-meta'), links: el.querySelector('.frame-links'), search: `${name} ${folder} ${description} level ${level} ${states.join(' ')}`.toLowerCase()};
    cards.push(card);
    setState(card, initial);
    select.addEventListener('change', () => setState(card, select.value));
    el.querySelector('.step').addEventListener('click', () => {
      playing = false; updatePlay();
      const next = (card.index + 1) % card.frames.length;
      card.origin = elapsed - next / (card.fps || 1);
      draw(card, next);
    });
    el.querySelector('.flip').addEventListener('click', (event) => {
      const flipped = el.querySelector('.stage').classList.toggle('flipped');
      event.currentTarget.setAttribute('aria-pressed', String(flipped));
    });
  }
}
zoom.addEventListener('change', () => cards.forEach(card => draw(card, card.index)));
const search = document.querySelector('#search');
function filter() {
  const query = search.value.trim().toLowerCase();
  for (const card of cards) card.el.hidden = !card.search.includes(query);
  for (const section of document.querySelectorAll('#gallery section')) section.hidden = !cards.some(card => card.section === section && !card.el.hidden);
  const count = cards.filter(card => !card.el.hidden).length;
  document.querySelector('#results').textContent = `${count} of ${cards.length} sprite groups${query ? ' match your search' : ' · Select an animation; open any frame to view its original PNG'}`;
  document.querySelector('#empty').hidden = count > 0;
}
search.addEventListener('input', filter);
filter();
const frameCount = Object.values(sprites).reduce((total, group) => total + Object.values(group).reduce((n, frames) => n + frames.length, 0), 0);
document.querySelector('#total').textContent = `${cards.length} groups / ${frameCount} frames`;
function tick(time) {
  if (previous !== null && playing && !document.hidden) elapsed += Math.min((time - previous) / 1000, 0.1) * Number(speed.value);
  previous = time;
  if (playing && !document.hidden) {
    for (const card of cards) {
      if (card.el.hidden || card.fps === 0) continue;
      const index = Math.floor((elapsed - card.origin) * card.fps) % card.frames.length;
      if (index !== card.index) draw(card, index);
    }
  }
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);
