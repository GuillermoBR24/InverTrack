# InverTrack App

Una aplicación móvil multiplataforma para gestionar y visualizar inversiones en tiempo real.

## 📱 Descripción

InverTrack es una aplicación Flutter completa que permite:
- 💼 Gestionar activos de inversión (acciones, criptomonedas, etc.)
- 📊 Visualizar resumen y detalle de la cartera de inversiones
- 📈 Monitorear datos de mercado en tiempo real
- 👤 Gestionar cuenta de usuario con autenticación segura
- 🖼️ Cargar y administrar imágenes de inversiones

## ✨ Características Principales

### Autenticación
- Login con correo y contraseña
- Registro de nuevos usuarios
- Recuperación de contraseña
- Sesión persistente

### Gestión de Inversiones
- Agregar nuevas inversiones
- Ver detalles individuales de cada activo
- Actualizar información de inversiones existentes
- Eliminar inversiones de la cartera
- Visualizar estadísticas por activo

### Cartera de Inversiones
- Resumen total de cartera
- Ganancia/Pérdida general
- Distribución de inversiones
- Análisis por tipo de activo

### Perfil de Usuario
- Vista y edición de información personal
- Gestión de preferencias
- Información de cuenta

## 🛠️ Stack Tecnológico

| Capa | Tecnología |
|------|-----------|
| **Framework** | Flutter 3.7.2+ |
| **Lenguaje** | Dart |
| **UI** | Material Design 3 |
| **Backend** | Supabase (PostgreSQL) |
| **Autenticación** | Supabase Auth |
| **Storage** | Supabase Storage |
| **Datos Mercado** | API REST personalizado |
| **Imágenes** | Google Fonts, Cached Network Image |

## 📁 Estructura del Proyecto

```
lib/
├── main.dart                    # Configuración y punto de entrada
├── screens/                     # Pantallas de la aplicación
│   ├── login_screen.dart       # Pantalla de autenticación
│   ├── register_screen.dart    # Registro de usuario
│   ├── home_screen.dart        # Dashboard principal
│   ├── profile_screen.dart     # Gestión de perfil
│   ├── add_asset_screen.dart   # Formulario para agregar inversiones
│   ├── asset_detail_invest_screen.dart    # Detalles de inversión individual
│   └── asset_portfolio_detail_screen.dart # Análisis de cartera
└── services/
    └── market_service.dart     # Llamadas a APIs de mercado
```

## 🚀 Configuración Rápida

### Requisitos
- Flutter 3.7.2 o superior
- Dart 3.4.0 o superior
- Android Studio / Xcode (para plataforma móvil)
- Conexión a internet

### Instalación

```bash
# 1. Clonar o descargar el proyecto
cd invertrack

# 2. Obtener dependencias
flutter pub get

# 3. Generar código necesario
flutter pub run build_runner build

# 4. Generar iconos de aplicación
flutter pub run flutter_launcher_icons:main

# 5. Ejecutar la aplicación
flutter run
```

## 🎨 Tema Personalizado

La aplicación utiliza un tema oscuro elegante:

- **Paleta de colores**:
  - Azul primario claro: `#4FC3F7`
  - Azul secundario: `#0288D1`
  - Fondo: `#0A0E1A`
  - Superficies: `#111827`
  - Contenedores: `#1E2D3D`

- **Material Design 3** para componentes modernos y consistentes

## 📦 Dependencias Principales

```yaml
supabase_flutter: ^2.5.0      # Backend y autenticación
google_fonts: ^6.1.0           # Tipografías modernas
image_picker: ^1.0.7          # Seleccionar imágenes
cached_network_image: ^3.3.1  # Caché inteligente de imágenes
http: ^1.2.1                  # Solicitudes HTTP
cupertino_icons: ^1.0.8       # Iconos iOS
```

## 🏗️ Arquitectura

La aplicación sigue un patrón modular:

- **Screens**: Componentes de UI independientes
- **Services**: Lógica de negocio y comunicación con APIs
- **Widgets**: Componentes reutilizables (implícitos en screens)

## 🔐 Variables de Entorno

Configuradas en `main.dart`:
- URL de Supabase
- Clave anónima de Supabase

**⚠️ Importante**: En producción, estas credenciales deben estar en un archivo seguro `.env` o variables de entorno.

## ▶️ Ejecutar la Aplicación

```bash
# Modo debug
flutter run

# Modo release
flutter run --release

# Especificar dispositivo
flutter run -d <device_id>

# Mostrar dispositivos disponibles
flutter devices
```

## 🏗️ Build para Distribución

### Android
```bash
# APK
flutter build apk --release

# App Bundle (Google Play)
flutter build app-bundle --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

### Otros
```bash
# Windows
flutter build windows --release

# Linux
flutter build linux --release

# macOS
flutter build macos --release
```

## 🧪 Testing

```bash
# Ejecutar pruebas
flutter test

# Con cobertura
flutter test --coverage
```

## 📊 Plataformas Soportadas

- ✅ Android (API 21+)
- ✅ iOS (11.0+)
- ✅ Web
- ✅ Windows 10+
- ✅ macOS 10.14+
- ✅ Linux

## 🐛 Solución de Problemas

### La aplicación no inicia
- Verifica: `flutter doctor`
- Ejecuta: `flutter clean && flutter pub get`

### Error de Supabase
- Confirma URL y credenciales en `main.dart`
- Verifica conexión a internet

### Imágenes no cargan
- Revisa permisos en manifiestos Android/iOS
- Verifica disponibilidad del URL

### Problemas en iOS
```bash
cd ios
rm -rf Pods Podfile.lock
cd ..
flutter clean
flutter pub get
flutter run
```

## 🔄 Actualizar Dependencias

```bash
# Ver qué está desactualizado
flutter pub outdated

# Actualizar dependencias
flutter pub upgrade

# Actualizar a versiones mayores
flutter pub upgrade --major-versions
```

## 📝 Convenciones de Código

- Utiliza `flutter_lints` para análisis estática
- Ejecuta: `flutter analyze`
- Formato: `dart format lib/`

## 🤝 Desarrollo

### Crear una nueva pantalla

1. Crear archivo en `lib/screens/`
2. Extender `StatelessWidget` o `StatefulWidget`
3. Implementar interfaz
4. Integrar en navegación

### Agregar nuevo servicio

1. Crear archivo en `lib/services/`
2. Implementar clase de servicio
3. Importar en pantallas que lo requieran

## 📚 Recursos Útiles

- [Documentación Flutter](https://flutter.dev/docs)
- [Supabase Docs](https://supabase.com/docs)
- [Material Design 3](https://m3.material.io/)
- [Dart Language](https://dart.dev/)

## 📄 Licencia

Proyecto privado. Contacta al propietario para más informacion.

---

**Versión**: 1.0.0  
**Última actualización**: Marzo 2026  
**Estado**: En desarrollo activo
