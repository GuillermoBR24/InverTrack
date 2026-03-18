# InverTrack

Una aplicación móvil multiplataforma desarrollada con Flutter para gestionar y visualizar inversiones en tiempo real.

## 📱 Descripción

InverTrack es una aplicación móvil completa que permite a los usuarios:
- **Gestionar inversiones**: Agregar, actualizar y eliminar activos de inversión
- **Visualizar cartera**: Ver el resumen y detalle de la cartera de inversiones
- **Monitoreo en tiempo real**: Acceder a datos de mercado actualizados
- **Análisis de activos**: Visualizar estadísticas detalladas por activo
- **Autenticación segura**: Sistema de login y registro con Supabase
- **Gestión de perfil**: Actualizar información de usuario

## 🛠️ Tecnologías

### Frontend
- **Framework**: Flutter 3.7.2+
- **Lenguaje**: Dart
- **UI Framework**: Material Design 3
- **Gestión de estado**: Provider (implícito en arquitectura actual)

### Backend & Servicios
- **Base de datos**: Supabase (PostgreSQL)
- **Autenticación**: Supabase Auth
- **APIs de Mercado**: Integración con servicios de datos de mercado
- **Storage**: Supabase Storage para imágenes

### Dependencias Principales
- **supabase_flutter** (v2.5.0) - Backend y autenticación
- **google_fonts** (v6.1.0) - Tipografías
- **image_picker** (v1.0.7) - Selección de imágenes
- **cached_network_image** (v3.3.1) - Caché de imágenes
- **http** (v1.2.1) - Llamadas HTTP

## 📁 Estructura del Proyecto

```
invertrack/
├── lib/
│   ├── main.dart                           # Punto de entrada
│   ├── screens/                            # Pantallas principales
│   │   ├── login_screen.dart              # Autenticación
│   │   ├── register_screen.dart           # Registro de usuarios
│   │   ├── home_screen.dart               # Pantalla principal
│   │   ├── profile_screen.dart            # Perfil de usuario
│   │   ├── add_asset_screen.dart          # Agregar inversiones
│   │   ├── asset_detail_invest_screen.dart # Detalle de inversión
│   │   └── asset_portfolio_detail_screen.dart # Detalle de cartera
│   └── services/
│       └── market_service.dart            # Servicios de datos de mercado
├── android/                                # Configuración Android nativa
├── ios/                                    # Configuración iOS nativa
├── web/                                    # Configuración Web
├── windows/                                # Configuración Windows
├── linux/                                  # Configuración Linux
├── macos/                                  # Configuración macOS
├── assets/                                 # Recursos (iconos, etc.)
└── pubspec.yaml                            # Dependencias y configuración

```

## 🚀 Requisitos Previos

- Flutter 3.7.2 o superior
- Dart 3.4.0 o superior
- Git
- Android Studio / Xcode (dependiendo de la plataforma)
- Una cuenta de Supabase activa

## 📦 Instalación y Configuración

### 1. Clonar el repositorio
```bash
git clone <repository-url>
cd InverTrack/invertrack
```

### 2. Instalar dependencias
```bash
flutter pub get
```

### 3. Configuración de valores generados
```bash
flutter pub run build_runner build
```

### 4. Generar iconos de aplicación
```bash
flutter pub run flutter_launcher_icons:main
```

## 🏃 Ejecución

### Desarrollo
```bash
# Ejecutar en el dispositivo/emulador conectado
flutter run

# Ejecutar con modo verbose para depuración
flutter run -v
```

### Build para Producción

**Android:**
```bash
flutter build apk --release
flutter build app-bundle --release
```

**iOS:**
```bash
flutter build ios --release
```

**Web:**
```bash
flutter build web --release
```

**Windows/Linux/macOS:**
```bash
flutter build windows --release
flutter build linux --release
flutter build macos --release
```

## 🎨 Tema

La aplicación utiliza un **tema oscuro personalizado** con:
- **Color primario**: Azul claro (#4FC3F7)
- **Color secundario**: Azul medio (#0288D1)
- **Fondo**: Azul oscuro casi negro (#0A0E1A)
- **Componentes**: Utiliza Material Design 3

## 🔒 Variables de Entorno

La aplicación utiliza credenciales de Supabase configuradas en `main.dart`:
- URL de Supabase
- Clave anónima de Supabase

**Nota**: Para seguridad en producción, estas credenciales deben moverse a un archivo de configuración seguro.

## 👥 Estructuras de Datos

### Usuario
- ID único
- Email
- Contraseña (hasheada)
- Información de perfil

### Activos de Inversión
- Nombre del activo
- Tipo (acciones, criptomonedas, etc.)
- Cantidad
- Precio de compra
- Fecha de adquisición
- Valor actual

### Cartera
- Resumen de inversiones
- Ganancia/Pérdida total
- Distribución de activos
- Historial de cambios

## 📊 Plataformas Soportadas

- ✅ Android (API 21+)
- ✅ iOS (11.0+)
- ✅ Web
- ✅ Windows
- ✅ macOS
- ✅ Linux

## 🐛 Problemas Conocidos y Soluciones

### Problemas Comunes

1. **Error de conexión a Supabase**
   - Verifica que tienes conexión a internet
   - Revisa las credenciales de Supabase en `main.dart`

2. **Imágenes no cargan**
   - Verifica permisos en Android/iOS
   - Comprueba la URL del servicio de almacenamiento

3. **Problemas de compilación en iOS**
   ```bash
   cd ios
   rm -rf Pods
   rm Podfile.lock
   flutter pub get
   cd ..
   flutter build ios
   ```

## 🔄 Actualización de Dependencias

```bash
# Ver dependencias desactualizadas
flutter pub outdated

# Actualizar dependencias
flutter pub upgrade

# Actualizar a versiones principales (cuidado)
flutter pub upgrade --major-versions
```

## 📝 Notas de Desarrollo

- **Linting**: Se utiliza `flutter_lints` para mantener la calidad del código
- **Testing**: Incluye configuración para pruebas unitarias en `test/`
- **Iconos**: Generados automáticamente con `flutter_launcher_icons`

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Asegúrate de:
1. Crear una rama para tu feature (`git checkout -b feature/amazing-feature`)
2. Commit tus cambios (`git commit -m 'Add some amazing feature'`)
3. Push a la rama (`git push origin feature/amazing-feature`)
4. Abrir un Pull Request

## 📄 Licencia

Este proyecto es privado. Para más información, contacta al propietario del proyecto.

## 📞 Soporte

Si tienes preguntas o problemas, por favor abre un issue en el repositorio.

---

**Última actualización**: Marzo 2026
**Estado**: En desarrollo activo
**Versión actual**: 1.0.0
