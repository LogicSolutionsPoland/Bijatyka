# Atomic Realm Assets Factory — lokalne paczki

Źródło: https://atomicrealm.itch.io

Ten katalog przeznaczony jest na **prywatne, lokalne** kopie trzech paczek dostarczonych przez właściciela projektu. Plików źródłowych nie dołączamy do publicznego repozytorium.

| Plik | Rozmiar | Zastosowanie |
| --- | ---: | --- |
| `[FREE] Interiors.zip` | 2 364 144 B | meble biurowe / wnętrza |
| `[AR] Post-Apocalyptic - Starter Pack.zip` | 38 902 278 B | ruiny miasta, barykady, samochody, otoczenie |
| `[FREE] Into The Wild.zip` | 18 487 756 B | obozowiska i roślinność |

## Kontrola integralności (SHA-256)
```text
855d51a2cb5cccc88e5c0ed5d218a1ea2e3f6c84010655ab1568186522614547  [FREE] Interiors.zip
19d0f01ad6fda1428ec61316d4e7b540c4f386a0e7850e9fee303b953961d798  [AR] Post-Apocalyptic - Starter Pack.zip
211be4b36b88cea9f414c55f9e40fdc1a2aef9889b032e824760b1278799cbc3  [FREE] Into The Wild.zip
```

## Licencja

Każde z oryginalnych archiwów zawiera plik `2. License.png`. Dopuszcza on wykorzystywanie i edycję modeli w projektach komercyjnych i niekomercyjnych, ale **zabrania przepakowywania, odsprzedaży i redystrybucji samych zasobów, również zmodyfikowanych**. Dlatego źródłowe ZIP/FBX/OBJ/GLB/tekstury pozostają lokalne i ignorowane przez Git.

## Użycie w Godot

W razie potrzeby wypakuj wybrane modele lokalnie i importuj odpowiednie `.glb` wraz z powiązanymi teksturami do własnej kopii projektu. Nie dodawaj surowych paczek do publicznej historii Git. Optymalizację i instancjonowanie modeli w grze wykonuj osobno; samo skatalogowanie paczek **nie zmienia mapy ani APK**.
