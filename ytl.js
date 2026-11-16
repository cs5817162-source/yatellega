(function () {
  var SB_URL = 'https://ercdafhhyhinnldeaplb.supabase.co';
  var SB_KEY = 'sb_publishable_jO4aeWshci1ZAoHnOuaDbQ_2mcUGUgU';
  window.sb = window.supabase.createClient(SB_URL, SB_KEY);
  window.$ = function (i) { return document.getElementById(i); };
  window.esc = function (t) { var d = document.createElement('div'); d.textContent = (t === null || t === undefined) ? '' : t; return d.innerHTML; };
  window.fmt = function (n) { return '$' + Math.round(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.'); };
  window.errMsg = function (e) {
    var m = (e && e.message) || String(e || '');
    if (/Invalid login/i.test(m)) return 'Correo o contraseña incorrectos.';
    if (/already registered/i.test(m)) return 'Ese correo ya tiene cuenta. Toca "Ya tengo cuenta".';
    if (/not confirmed/i.test(m)) return 'Falta confirmar tu correo. Revisa tu bandeja de entrada.';
    if (/rate limit|too many/i.test(m)) return 'Muchos intentos. Espera unos minutos e inténtalo de nuevo.';
    if (/at least 6|weak/i.test(m)) return 'La contraseña debe tener mínimo 6 caracteres.';
    if (/valid email|invalid format/i.test(m)) return 'Escribe un correo válido.';
    if (/duplicate key|unique/i.test(m)) return 'Ese dato ya está registrado.';
    if (/Failed to fetch|network/i.test(m)) return 'No hay internet. Revisa tu conexión.';
    return 'Algo falló: ' + m;
  };
  window.casilla = function (el, cb) {
    function t() {
      var s = !el.classList.contains('sel');
      el.classList.toggle('sel', s);
      el.setAttribute('aria-checked', s ? 'true' : 'false');
      el.querySelector('.caja').textContent = s ? '✓' : '';
      cb(s);
    }
    el.addEventListener('click', t);
    el.addEventListener('keydown', function (e) { if (e.key === ' ' || e.key === 'Enter') { e.preventDefault(); t(); } });
  };
  window.salir = function () { sb.auth.signOut().then(function () { location.reload(); }); };
  window.entrar = function (box, titulo, onOk) {
    var crear = false;
    sb.auth.getSession().then(function (r) {
      var s = r.data && r.data.session;
      if (s) { onOk(s.user); return; }
      pintar();
    });
    function pintar() {
      box.style.display = 'block';
      box.innerHTML = '<div class="au"><h1>' + titulo + '</h1><p class="au-s">' + (crear ? 'Crea tu cuenta con tu correo y una contraseña.' : 'Entra con tu correo y tu contraseña.') + '</p>' +
        '<label for="au-c">Correo</label><input type="email" id="au-c" autocomplete="email" placeholder="nombre@correo.com">' +
        '<label for="au-p">Contraseña</label><input type="password" id="au-p" autocomplete="' + (crear ? 'new-password' : 'current-password') + '" placeholder="Mínimo 6 caracteres">' +
        '<button class="au-b" id="au-go" type="button">' + (crear ? 'Crear cuenta' : 'Entrar') + '</button>' +
        '<div class="au-e" id="au-e" role="alert"></div>' +
        '<button class="au-l" id="au-sw" type="button">' + (crear ? 'Ya tengo cuenta' : 'No tengo cuenta: crear una') + '</button></div>';
      $('au-sw').onclick = function () { crear = !crear; pintar(); };
      $('au-go').onclick = go;
      $('au-p').onkeydown = function (e) { if (e.key === 'Enter') go(); };
    }
    function go() {
      var c = $('au-c').value.trim(), p = $('au-p').value, e = $('au-e');
      if (!/^\S+@\S+\.\S+$/.test(c)) { e.textContent = 'Escribe un correo válido.'; return; }
      if (p.length < 6) { e.textContent = 'La contraseña debe tener mínimo 6 caracteres.'; return; }
      e.textContent = 'Un momento…';
      $('au-go').disabled = true;
      var q = crear ? sb.auth.signUp({ email: c, password: p }) : sb.auth.signInWithPassword({ email: c, password: p });
      q.then(function (r) {
        $('au-go').disabled = false;
        if (r.error) { e.textContent = errMsg(r.error); return; }
        if (r.data && r.data.session) { box.style.display = 'none'; onOk(r.data.session.user); return; }
        e.textContent = 'Te enviamos un correo para confirmar la cuenta. Ábrelo, confirma y luego entra.';
      });
    }
  };
})();
