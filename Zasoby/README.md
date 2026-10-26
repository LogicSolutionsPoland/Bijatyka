# Zasoby Bijatyki — katalog 34 paczek

Ten katalog dotyczy źródłowych paczek modeli, tekstur, animacji, VFX i shaderów przekazanych do projektu. Dokładna lista znajduje się w [manifest.json](manifest.json), łącznie z rozmiarami plików oraz stanem weryfikacji licencji.

**Uwaga:** ten commit dodaje ewidencję i narzędzie lokalnego importu; **nie oznacza przesłania 34 binarnych archiwów do GitHuba ani ich użycia przez grę**. Oryginały pozostają w bibliotece ChatGPT w folderze `/zasoby`. Biblioteka ChatGPT nie jest zewnętrznym adresem URL, z którego GitHub Actions może automatycznie pobrać te pliki.

## Bezpieczeństwo licencji

- **CC0 potwierdzone w paczkach:** `1-bit-godot-shader-free-project.zip`, `pencil-godot-shader-free-project (1).zip`, `brackeys_vfx_bundle.zip`. KayKit 1.1 także ma w repo licencję CC0.
- **Nie wolno publikować osobnych źródłowych archiwów na podstawie obecnej dokumentacji:** `[AR] Post-Apocalyptic - Starter Pack.zip`, `[FREE] Interiors.zip`, `[FREE] Into The Wild.zip`; wcześniejszy audyt AtomicRealm wskazał zakaz redystrybucji źródeł.
- **Licencja wymaga sprawdzenia:** wszystkie pozostałe paczki, nawet jeśli w nazwie występuje „free”. Gratis nie oznacza prawa do redystrybucji. `PSX Graveyard Demo.zip` traktujemy jako demo/referencję, a nie potwierdzony asset do gry.
- **Nie duplikujemy zasobów już zaimportowanych:** `third_party/kaykit_character_animations_1_1`, `third_party/universal_animation_library_standard` oraz `game/shaders/pencil*.gdshader` istnieją już w gałęzi bazowej.

Repozytorium jest publiczne. Nie publikuj obcych paczek źródłowych bez zgody odpowiedniej licencji. Przy paczkach >100 MiB zwykły GitHub odrzuca pliki; nawet dla materiałów możliwych do redystrybucji należy rozważyć Git LFS lub dystrybucję po stronie dostawcy.

## Użycie lokalne (Cloud Shell / terminal)

1. Sklonuj tę gałąź lub przełącz się na nią.
2. Prześlij legalnie pozyskane oryginalne paczki z własnego urządzenia do jednego katalogu w Cloud Shell.
3. Uruchom:

```bash
python3 tools/import_zasoby.py /ścieżka/do/przesłanych/paczek --check-only
python3 tools/import_zasoby.py /ścieżka/do/przesłanych/paczek
```

Skrypt sprawdza rozmiary i znane sumy SHA-256, po czym kopiuje paczki bez rozpakowywania do ignorowanego przez Git katalogu `Zasoby/local/`. Nie usuwa źródeł. Nie modyfikuje scen Godot, nie uruchamia GitHub Actions, nie wymusza publikacji plików.

## Dalsze wdrażanie do gry

Importuj tylko **konkretne, przydatne elementy** (np. zoptymalizowane tekstury VFX, skorygowane modele, animacje po retargetingu) po sprawdzeniu licencji i budżetu wydajności Android ARM64. Samo dodanie archiwum do repozytorium nie sprawia, że Godot go wykorzystuje.

Kontynuację starszych katalogów opisują [AtomicRealm](AtomicRealm/README.md) oraz [HorrorEnvironmentVFX](HorrorEnvironmentVFX/README.md).
