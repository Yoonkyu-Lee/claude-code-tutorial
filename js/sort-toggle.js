// 목록 정렬 토글: 기본 최신순(빌드 순서), 버튼으로 오래된순 전환. localStorage에 기억.
// 대상: 좌측 네비의 채널 글 목록(leaf nav list) + 본문 INDEX의 날짜 표.
(function () {
  var KEY = 'listSort'; // 'newest' | 'oldest'
  function get() { try { return localStorage.getItem(KEY) || 'newest'; } catch (e) { return 'newest'; } }
  function set(v) { try { localStorage.setItem(KEY, v); } catch (e) {} }

  function reverseChildren(el) {
    var kids = Array.prototype.slice.call(el.children);
    for (var i = kids.length - 1; i >= 0; i--) el.appendChild(kids[i]);
  }
  // 네비의 "leaf" 목록(하위 목록이 없는 = 채널의 글 목록)만 대상
  function leafNavLists() {
    return Array.prototype.filter.call(
      document.querySelectorAll('.md-sidebar--primary .md-nav__list'),
      function (ul) { return !ul.querySelector('.md-nav__list'); }
    );
  }
  function isDateTable(tbl) {
    var th = tbl.querySelector('thead th');
    if (th && /(게시일|날짜|date)/i.test(th.textContent)) return true;
    var td = tbl.querySelector('tbody td');
    return !!(td && /^\s*\d{4}-\d{2}-\d{2}/.test(td.textContent));
  }

  // 빌드 순서 = 최신순. oldest면 뒤집는다. (중복 적용 방지 위해 플래그 기록)
  function applyNav(order) {
    var want = (order === 'oldest');
    if (document.body.dataset.navRev === String(want)) return;
    leafNavLists().forEach(reverseChildren);
    document.body.dataset.navRev = String(want);
  }
  function applyTables(order) {
    var want = (order === 'oldest');
    document.querySelectorAll('.md-content table').forEach(function (tbl) {
      if (!isDateTable(tbl)) return;
      var tb = tbl.querySelector('tbody'); if (!tb) return;
      if (tbl.dataset.rev === String(want)) return;
      reverseChildren(tb);
      tbl.dataset.rev = String(want);
    });
  }
  function apply(order) { applyNav(order); applyTables(order); }

  function injectToggle() {
    var host = document.querySelector('.md-content article') || document.querySelector('.md-content');
    if (!host || document.getElementById('sort-toggle')) return;
    var b = document.createElement('button');
    b.id = 'sort-toggle';
    b.type = 'button';
    b.style.cssText = 'font-size:.72rem;margin:.1rem 0 1rem;padding:.15rem .55rem;border:1px solid var(--md-default-fg-color--lightest);border-radius:.4rem;background:transparent;color:var(--md-default-fg-color--light);cursor:pointer;';
    function label() { b.textContent = '정렬: ' + (get() === 'oldest' ? '오래된순' : '최신순') + ' ⇅'; }
    label();
    b.addEventListener('click', function () {
      set(get() === 'oldest' ? 'newest' : 'oldest');
      label();
      apply(get());
    });
    var lv = document.getElementById('last-viewed-note');
    if (lv && lv.parentNode) lv.parentNode.insertBefore(b, lv.nextSibling);
    else host.insertBefore(b, host.firstChild);
  }

  function run() { injectToggle(); apply(get()); }
  if (typeof window.document$ !== 'undefined' && window.document$.subscribe) window.document$.subscribe(run);
  else if (document.readyState !== 'loading') run();
  else document.addEventListener('DOMContentLoaded', run);
})();
