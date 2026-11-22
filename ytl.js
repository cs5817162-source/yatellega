(function () {
  var SB_URL = 'https://ercdafhhyhinnldeaplb.supabase.co';
  var SB_KEY = 'sb_publishable_jO4aeWshci1ZAoHnOuaDbQ_2mcUGUgU';

  // Cada pantalla guarda su propia sesion. Asi, en un mismo celular se
  // puede estar dentro como cliente, como conductor y en el panel al
  // mismo tiempo, sin que una saque a la otra. Sirve para hacer pruebas
  // con un solo telefono, y tambien para quien pide y ademas maneja.
  var pagina = (location.pathname.split('/').pop() || 'index').replace('.html', '');
  if (pagina === 'motero') pagina = 'conductor';
  var CLAVE_SESION = 'ytl-' + (pagina || 'index');

  window.sb = window.supabase.createClient(SB_URL, SB_KEY, {
    auth: { storageKey: CLAVE_SESION }
  });
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
  // ------------------------------------------------------------------
  // SONIDOS
  // Se generan en el momento, no hay archivos que descargar. Suenan al
  // volumen que el celular ya tenga puesto: la app NUNCA lo sube. Eso
  // importa porque el conductor va en moto, muchas veces con audifonos.
  // ------------------------------------------------------------------
  var ctx = null, repite = null;

  function mudo() {
    try { return localStorage.getItem('ytl-mudo') === '1'; } catch (e) { return false; }
  }
  window.estaMudo = mudo;
  window.ponerMudo = function (s) {
    try { localStorage.setItem('ytl-mudo', s ? '1' : '0'); } catch (e) {}
    if (s) window.alertaRepetida(false);
  };

  // Los navegadores solo dejan sonar despues de que la persona toca algo.
  // Por eso esto se llama al conectarse o al pedir.
  window.prepararSonido = function () {
    try {
      if (!ctx) ctx = new (window.AudioContext || window.webkitAudioContext)();
      if (ctx.state === 'suspended') ctx.resume();
    } catch (e) { ctx = null; }
  };

  function nota(hz, desde, dura, vol) {
    var o = ctx.createOscillator(), g = ctx.createGain();
    o.type = 'sine';
    o.frequency.setValueAtTime(hz, desde);
    g.gain.setValueAtTime(0.0001, desde);
    g.gain.exponentialRampToValueAtTime(vol, desde + 0.02);
    g.gain.exponentialRampToValueAtTime(0.0001, desde + dura);
    o.connect(g); g.connect(ctx.destination);
    o.start(desde); o.stop(desde + dura + 0.03);
  }

  // Pedido nuevo: tres notas que suben, para que se oiga en la calle
  window.sonarAlerta = function () {
    if (mudo()) return;
    if (navigator.vibrate) { try { navigator.vibrate([140, 80, 140]); } catch (e) {} }
    if (!ctx) return;
    var t = ctx.currentTime;
    nota(784, t, 0.15, 0.26);
    nota(1047, t + 0.16, 0.15, 0.26);
    nota(1319, t + 0.32, 0.30, 0.26);
  };

  // Algo paso con tu pedido: dos notas suaves
  window.sonarAviso = function () {
    if (mudo()) return;
    if (navigator.vibrate) { try { navigator.vibrate(90); } catch (e) {} }
    if (!ctx) return;
    var t = ctx.currentTime;
    nota(659, t, 0.14, 0.18);
    nota(988, t + 0.15, 0.26, 0.18);
  };

  // Mientras el pedido espera respuesta, sigue sonando cada 2,5 segundos
  window.alertaRepetida = function (encendido) {
    if (repite !== null) { clearInterval(repite); repite = null; }
    if (!encendido) return;
    window.sonarAlerta();
    repite = setInterval(window.sonarAlerta, 2500);
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
      box.style.display = 'block'; var cg = document.getElementById('cargando') || document.getElementById('carga'); if (cg) cg.style.display = 'none';
      box.innerHTML = '<div class="au"><img src="logo.png" alt="Ya te llega" style="display:block;width:96px;height:96px;margin:0 auto 6px"><h1>' + titulo + '</h1><p class="au-s">' + (crear ? 'Crea tu cuenta con tu correo y una contraseña.' : 'Entra con tu correo y tu contraseña.') + '</p>' +
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
