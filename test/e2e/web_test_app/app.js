// ---- State ----
var count = 0;
var loggedIn = false;

var emojis = ['🎬','🎵','🎮','📸','🍕','💡','🚀','🎨','📚','🏋️','✈️','🎭','🐶','🌮','⚽','🎸','💻','🌿','🎯','🔥'];
var users = ['Alex','Jordan','Sam','Riley','Casey','Morgan','Taylor','Quinn','Avery','Drew','Blake','Harper','Sage','Rowan','Sky','River','Phoenix','Ash','Storm','Luna'];
var titles = ['Amazing sunset today','New recipe alert!','Check out this beat','Travel diaries pt.3','Gym transformation','My cat did WHAT','Code review gone wrong','Unboxing haul','Painting timelapse','Cooking challenge','Morning routine','Study with me','Room tour 2024','Life hack you need','Thrift flip','Day in my life','Book recommendations','Workout motivation','Street food review','Art process'];
var descs = [
  'This is honestly one of the best things I\'ve ever seen. You won\'t believe what happens next!',
  'Just tried this for the first time and I\'m obsessed. Let me know what you think in the comments!',
  'Been working on this for weeks and finally ready to share with everyone. Hope you enjoy!',
  'Something different today — stepping out of my comfort zone. Your support means everything.',
  'Can\'t stop watching this on repeat. The vibes are immaculate.'
];
var gradients = [
  'linear-gradient(135deg, #667eea, #764ba2)',
  'linear-gradient(135deg, #f093fb, #f5576c)',
  'linear-gradient(135deg, #4facfe, #00f2fe)',
  'linear-gradient(135deg, #43e97b, #38f9d7)',
  'linear-gradient(135deg, #fa709a, #fee140)',
  'linear-gradient(135deg, #a18cd1, #fbc2eb)',
  'linear-gradient(135deg, #fccb90, #d57eeb)',
  'linear-gradient(135deg, #e0c3fc, #8ec5fc)'
];

// ---- Login ----
function doLogin() {
  var email = document.getElementById('email_input').value;
  var pass = document.getElementById('password_input').value;
  var err = document.getElementById('login_error');

  if (!email || !pass) {
    err.textContent = 'Please enter email and password';
    err.style.display = 'block';
    return;
  }
  if (pass.length < 4) {
    err.textContent = 'Password too short';
    err.style.display = 'block';
    return;
  }

  err.style.display = 'none';
  loggedIn = true;
  document.getElementById('login-page').classList.remove('active');
  document.getElementById('home-page').classList.add('active');
  document.getElementById('bottom_nav').classList.add('show');
  buildFeed();
  buildBrowseList();
  buildMyPosts();
}

function doLogout() {
  loggedIn = false;
  document.querySelectorAll('.page').forEach(function(p) { p.classList.remove('active'); });
  document.getElementById('login-page').classList.add('active');
  document.getElementById('bottom_nav').classList.remove('show');
  document.getElementById('email_input').value = '';
  document.getElementById('password_input').value = '';
  showToast('Logged out');
}

// ---- Navigation ----
function switchTab(name) {
  document.querySelectorAll('.page').forEach(function(p) { p.classList.remove('active'); });
  document.querySelectorAll('.nav-tab').forEach(function(t) { t.classList.remove('active'); });
  document.getElementById(name + '-page').classList.add('active');
  document.getElementById('nav_' + name).classList.add('active');
}

// ---- Counter ----
function increment() { count++; updateCounter(); }
function decrement() { count--; updateCounter(); }
function updateCounter() { document.getElementById('counter_display').textContent = 'Count: ' + count; }

// ---- Post submit ----
function submitPost() {
  var text = document.getElementById('post_input').value;
  document.getElementById('post_result').textContent = text ? 'Posted: ' + text : '';
  if (text) showToast('📝 Posted: ' + text);
}

// ---- Feed ----
function buildFeed() {
  var feed = document.getElementById('feed');
  if (feed.children.length > 0) return;
  var html = '';
  for (var i = 0; i < 20; i++) {
    var likes = Math.floor(Math.random() * 50000);
    var comments = Math.floor(Math.random() * 5000);
    var time = Math.floor(Math.random() * 24) + 'h ago';
    var grad = gradients[i % gradients.length];
    html += '<div class="card" id="feed_item_' + i + '">' +
      '<div class="card-header">' +
        '<div class="card-avatar">' + emojis[i % emojis.length] + '</div>' +
        '<span class="card-user">' + users[i % users.length] + '</span>' +
        '<span class="card-time">' + time + '</span>' +
      '</div>' +
      '<div class="card-image" style="background:' + grad + '">' + emojis[i % emojis.length] + '</div>' +
      '<div class="card-body">' + descs[i % descs.length] + '</div>' +
      '<div class="card-actions">' +
        '<button class="card-action" id="post_like_button_' + i + '" onclick="likePost(this,' + likes + ')">❤️ ' + fmtNum(likes) + '</button>' +
        '<button class="card-action" id="post_comment_button_' + i + '" onclick="showToast(\'💬 Comments\')">💬 ' + fmtNum(comments) + '</button>' +
        '<button class="card-action" id="post_share_button_' + i + '" onclick="showToast(\'↗️ Shared!\')">↗️ Share</button>' +
      '</div>' +
    '</div>';
  }
  feed.innerHTML = html;
}

function fmtNum(n) { return n >= 1000 ? (n / 1000).toFixed(1) + 'K' : String(n); }

function likePost(btn, count) {
  btn.classList.toggle('active');
  var liked = btn.classList.contains('active');
  var num = liked ? count + 1 : count;
  btn.innerHTML = (liked ? '❤️' : '🤍') + ' ' + fmtNum(num);
  showToast(liked ? '❤️ Liked!' : '💔 Unliked');
}

// ---- Search ----
function onSearch() {
  var q = document.getElementById('search_input').value.toLowerCase();
  var results = document.getElementById('search_results');
  if (!q) { results.innerHTML = ''; return; }
  var html = '';
  titles.forEach(function(t, i) {
    if (t.toLowerCase().indexOf(q) !== -1) {
      html += '<div class="card"><div style="font-weight:600;margin-bottom:4px">' + t + '</div><div style="color:var(--text2);font-size:13px">by ' + users[i % users.length] + '</div></div>';
    }
  });
  results.innerHTML = html || '<p style="color:var(--text2);text-align:center;padding:20px">No results found</p>';
}

function setFilter(el, name) {
  document.querySelectorAll('.filter-chip').forEach(function(c) { c.classList.remove('active'); });
  el.classList.add('active');
  showToast('Filter: ' + name);
}

function buildBrowseList() {
  var list = document.getElementById('browse_list');
  if (list.children.length > 0) return;
  var html = '';
  for (var i = 0; i < 50; i++) {
    html += '<div class="list-item" id="browse_item_' + i + '">' +
      '<span>' + emojis[i % emojis.length] + ' Trending item #' + (i + 1) + '</span>' +
      '<span style="color:var(--text2);font-size:12px">#' + (i + 1) + '</span>' +
    '</div>';
  }
  list.innerHTML = html;
}

// ---- Create ----
function toggleSwitch(el) { el.classList.toggle('on'); }

function publishPost() {
  var title = document.getElementById('create_title_input').value;
  if (!title) { showToast('⚠️ Please add a title'); return; }
  showToast('🚀 Published: ' + title);
  document.getElementById('create_title_input').value = '';
  document.getElementById('create_body_input').value = '';
}

// ---- Profile ----
function buildMyPosts() {
  var container = document.getElementById('my_posts');
  if (container.children.length > 0) return;
  var html = '';
  for (var i = 0; i < 8; i++) {
    html += '<div class="card" id="my_post_' + i + '"><div style="font-weight:600;margin-bottom:4px">' + titles[i] + '</div><div style="color:var(--text2);font-size:13px">' + descs[i % descs.length].slice(0, 80) + '...</div></div>';
  }
  container.innerHTML = html;
}

function updateSlider(id) {
  var el = document.getElementById(id);
  document.getElementById(id + '_value').textContent = el.value;
}

// ---- Settings Modal ----
function openSettings() { document.getElementById('settings_modal').classList.add('show'); }
function closeSettings() { document.getElementById('settings_modal').classList.remove('show'); }

// ---- Toast ----
function showToast(msg) {
  var t = document.getElementById('toast');
  t.textContent = msg;
  t.classList.add('show');
  clearTimeout(t._timer);
  t._timer = setTimeout(function() { t.classList.remove('show'); }, 2500);
}

// ---- Back handler for flutter-skill ----
window.__flutterSkillGoBack = function () {
  if (document.getElementById('settings_modal').classList.contains('show')) {
    closeSettings();
    return;
  }
  if (loggedIn) {
    switchTab('home');
  }
};
