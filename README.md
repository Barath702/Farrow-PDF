# 📄 Farrow PDF Reader

**Farrow PDF Reader** is a fast, lightweight, and smooth PDF viewer built with Flutter.
Designed for performance and simplicity, it delivers a premium reading experience with fluid navigation, clean UI, and optimized rendering — even on low-end devices.

---

## 🚀 Features

* ⚡ **Ultra-smooth scrolling** (120Hz optimized)
* 📖 **Continue reading** (auto resume from last page)
* 🔖 **Bookmarks** (page-specific)
* 🕘 **History tracking** (recently opened PDFs)
* 📂 **Auto PDF detection** from device storage
* 🖼️ **Thumbnail previews** (first page rendering)
* 🌙 **Optional night mode**
* 🔍 **Fast page navigation**
* 🧈 **Minimal & modern UI**
* 📉 **Lightweight & efficient**

---

## 📱 Screenshots

> *(Add your screenshots here)*

---

## 🏗️ Built With

* **Flutter**
* **Dart**
* **pdfrx** (PDF rendering engine)
* **Provider** (state management)

---

## ⚙️ Installation

### 1. Clone the repository

```bash
git clone https://github.com/your-username/farrow-pdf-reader.git
cd farrow-pdf-reader
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Run the app

```bash
flutter run
```

---

## 📦 Build APK

```bash
flutter build apk --release
```

---

## 📂 Project Structure

```
lib/
 ├── screens/
 │    ├── home_screen.dart
 │    ├── pdf_viewer_screen.dart
 │
 ├── providers/
 │    ├── reader_provider.dart
 │
 ├── widgets/
 │    ├── pdf_thumbnail.dart
 │
 ├── services/
 │    ├── file_service.dart
 │
 └── main.dart
```

---

## 🧠 Key Highlights

* **Optimized rendering pipeline** for fast PDF loading
* **Background thumbnail generation** for smooth UI
* **Smart caching** to avoid reloading PDFs
* **Gesture-driven UI** with tap-to-toggle controls
* **Kinetic scrolling** for natural navigation

---

## ⚠️ Permissions

The app requires storage access to:

* Read PDF files from device storage
* Display and manage documents

---

## 🔒 Notes

* Designed primarily for **offline usage**
* Some PDFs (scanned/image-based) may not support text selection
* Performance may vary based on device and PDF size

---

## 📌 Roadmap

* 🔍 In-PDF text search
* ✏️ Annotation system (highlight/draw)
* ☁️ Cloud sync support
* 📑 Multi-tab reading

---

## 🤝 Contributing

Contributions are welcome!

1. Fork the repo
2. Create a new branch
3. Commit your changes
4. Open a Pull Request

---

## ⭐ Support

If you like this project, consider giving it a ⭐ on GitHub!

---
