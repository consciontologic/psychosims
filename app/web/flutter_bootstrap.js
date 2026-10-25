{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    renderer: 'canvaskit',
    canvasKitBaseUrl: 'canvaskit/',
    fontFallbackBaseUrl: 'fonts/',
    hostElement: document.querySelector('#flutter-host'),
  },
});
