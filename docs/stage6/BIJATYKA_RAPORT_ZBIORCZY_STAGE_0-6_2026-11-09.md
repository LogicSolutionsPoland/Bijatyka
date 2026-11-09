# BIJATYKA — raport zbiorczy etapów 0–6, wraz z Stage 5B (Steps 0–6)

**Data sporządzenia:** 2026-11-09 (Europe/Warsaw)  
**Repozytorium:** https://github.com/LogicSolutionsPoland/Bijatyka  
**Silnik:** Godot 4.7.2; GL Compatibility; Android ARM64  
**Zakres:** historia audytu, integracji, weryfikacji, budowy Android APK i brakujących testów urządzeniowych.  
**Status całości:** **PARTIAL — BUILD PASS, PHYSICAL DEVICE TESTING NOT TESTED.**  
**Lokalizacja zapisu:** gałąź techniczna build/bijatyka-stage6-final-arm64-20261109; dokumentacja, bez zmian w grze.

> **Zasada interpretacji:** PASS w GitHub Actions oznacza wyłącznie potwierdzoną bramkę CI. Zakończony build APK nie oznacza, że gra działa poprawnie na fizycznym telefonie. W historii są różne plany etapów o podobnych nazwach; niniejszy raport obejmuje ciąg weryfikacji z 8–9 listopada 2026 oraz powstałą z niego integrację Stage 5B i finalny build Stage 6. Historycznych osobnych etapów skoków/QTE nie uznaje się za tożsame z etapami tego audytu.

## 1. Streszczenie i ostateczna decyzja

- **Właściwy, przetestowany kod gry:** f1989c8c675357427e2214796e14a5103f1cef01 z gałęzi integration/bijatyka-stage5b-blackout-fog-20261109.
- **Ostatni obserwowany HEAD tej gałęzi:** 2c031f702b01bee3579a9d6856f6459a203b86a7. Porównanie z przetestowanym SHA: dokładnie dwa commity i tylko docs/stage5b/STAGE5B_STATE.md; brak zmian plików produkcyjnych.
- **Ostatni pozytywny kompleksowy test Stage 5B:** [Actions #42677244923](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42677244923), SUCCESS, na SHA f1989c8c675357427e2214796e14a5103f1cef01.
- **Finalny build Stage 6:** [Actions #42687863317](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42687863317), SUCCESS. Workflow commit ddac53d03946f874cc4307b0849ecd5e31044897, lecz checkout **dokładnie źródła f1989c8...**, nie starego main.
- **APK:** Bijatyka-Stage6-Final-ARM64.apk, 66 373 509 bajtów, SHA-256 **4e64243e254c8fb5b2a713dae6ea23be09447833a7ea49572197df5d3d392d4f**.
- **Archiwum GitHub Actions:** [artefakt #13706246072](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42687863317/artifacts/13706246072), nazwa ZIP: Bijatyka-Stage6-Final-ARM64. Artefakt jest archiwum ZIP zawierającym APK, nie bezpośrednim linkiem do surowego APK. W momencie sprawdzenia: istnieje, expired=false, data wygaśnięcia 2026-12-09.
- **Własności gry zachowane:** rzeczywisty fullscreen blackout na ziemi, 10 m circular Zombie Fog Horizon, oryginalne grafiki PR #68/#70, 3D snop latarki, Exo Gray, sterowanie padem, walka/skoki/magia, AI, chwyt i QTE, winda, respawn, character-only Pencil Sketch.
- **Fizyczny Android:** brak przedstawionych dowodów instalacji, FPS, temperatury, zachowania pada i pełnego przejazdu windą. **Nie oznaczać Stage 6 jako pełnego DEVICE PASS.**

## 2. Mapa głównych etapów weryfikacji (8–9 listopada 2026)

| Etap | Cel | Potwierdzony wynik | Wniosek / ograniczenie |
| --- | --- | --- | --- |
| Stage 0 | Inwentaryzacja repozytorium i funkcji | **COMPLETE — audyt read-only** | main ac12a215... był starszym zestawem funkcji; sprawdzono strukturę PR i główny workflow #42520169767 (SUCCESS); brak zmian lub APK |
| Stage 1 | Testy automatyczne mechanik na historycznym main | **PARTIAL: 35/38 PASS, 3 FAIL**, dodatkowo 5 obszarów nieprzetestowanych | Problem doskoku przy ścianie; test blasku zębów; timeout sondy snopa; nie wolno traktować starego main jako kompletnej gry |
| Stage 1 — follow-up | Naprawa zachowania doskoku przy przeszkodzie | **PASS dla oddzielnego zakresu** | QA branch qa/stage1-wall-doskok-20261108, SHA 3626daa5ad552e1b1448ad999addd1e38b8d70f3, [Actions #42530999351](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42530999351) SUCCESS; 13/13 kontroli i smoke 600 klatek; bez merge do main |
| Stage 2 | Render, kamera, animacje i zrzuty prawdziwych klatek | **PARTIAL** | 6/6 testów renderingu PASS i 32 zrzuty starego main; potwierdzona przeszkadzająca barierka na dachu, analiza kopnięcia niejednoznaczna; niepełne sekwencje walki, magii, grabów i windy |
| Stage 3 | Początkowy build Android i test telefonu | **PARTIAL — build PASS, telefon NOT TESTED** | [Actions #42573037879](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42573037879) SUCCESS, lecz wcześniejszy APK powstał ze starszej bazy funkcji; użytkownik zgłosił przestarzałą rozgrywkę; APK nie należy używać jako finalnego |
| Stage 4 | Zebranie nowszych kompatybilnych gałęzi | **PASS w CI, bez merge do main** | integration/bijatyka-current-20261109, SHA 86ddc8cdb8e883a83f0b8978e7f94f69df27f3b0, [Actions #42584274228](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42584274228) SUCCESS po wcześniejszych nieudanych próbach |
| Stage 5 | Dalsza integracja i regresje, bez APK | **CI PASS / ZAKRES PARTIAL** | integration/bijatyka-stage5-complete-20261109, SHA b052aaf876f5cb141547494b62b8c2fdb473e6c4, [Actions #42623536580](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42623536580) SUCCESS, 20/20 zestawów, smoke 600 klatek; **PR #68 i #70 nie były jeszcze zintegrowane; blackout na ziemi był nieobecny** |
| Stage 5B | Przywrócenie blackout, integracja PR #68 i #70, testy końcowe | **PASS WITH LIMITATIONS (CI)** | szczegółowy przebieg poniżej; prawdziwy rendering Mesa/OpenGL, ale nie urządzenie |
| Stage 6 | Ostateczny Android ARM64 APK z Stage 5B | **BUILD PASS / DEVICE NOT TESTED** | aktualny APK, poprawny SHA źródła, podpis i zasoby potwierdzone; brak danych fizycznego telefonu |

### 2.1. Dlaczego Stage 3 nie stanowiło akceptacji finalnej

Historyczny main: **ac12a215d95ce85d982f68b469aea99e75542883**. Wynik starszej próby Androida: workflow #42573037879, APK z sumą SHA-256 **6e034c89967b59c17417d19fd8d65f46f3060a1eccf67005692b55d0c749c200**. Ten pakiet nie zawierał kompletnej, później zintegrowanej wersji Stage 5B. Build mógł przejść poprawnie, ale wybór źródła był niewłaściwy do aktualnej rozgrywki. Rozwiązaniem było odrębne scalenie mechanik do Stage 4/5, a następnie integracja Stage 5B i zamrożenie dokładnego SHA do Stage 6.

### 2.2. Konsekwencje Stage 5

Stage 5 zebrał aktualniejsze systemy ruchu, przeciwników, walki, sterowania, widoczności i wydajności; jednak **nie był końcową podstawą do wydania na Androida**, bo brakowało obowiązkowego fullscreen blackout i adaptacji efektów z PR #68 oraz PR #70. Dalsza praca odbyła się na nowej gałęzi Stage 5B bez powrotu do main.

## 3. Stage 5B — wszystkie siedem kroków (0–6)

**Autorytatywny dziennik:** [docs/stage5b/STAGE5B_STATE.md](https://github.com/LogicSolutionsPoland/Bijatyka/blob/integration/bijatyka-stage5b-blackout-fog-20261109/docs/stage5b/STAGE5B_STATE.md).

| Krok | Realnie wykonana praca | Dowód GitHub Actions | Status |
| --- | --- | --- | --- |
| Step 0 | Audyt Stage 5, porównanie PR #68/#70, zaplanowanie testów; utworzenie bezpiecznej gałęzi i dziennika | Dokument Stage5B, baza b052aaf... | **PASS — audit/setup** |
| Step 1 | Przywrócono pełnoekranową czarną maskę na ziemi, zachowano HUD, postać, snop i profil dachu | [#42641061088](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42641061088), SHA 738eb0064a02ba3aca13af31f3829733c695e40e | **PASS** |
| Step 2 | Zaadaptowano 10-metrowy okrągły horyzont zombie: 96 segmentów, 6 sektorów, cztery WebP, animacja i podążanie za graczem | [#42649851614](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42649851614), SHA a51ed9c4de20df3126b0865f781b1a9a89ab9051 | **PASS** |
| Step 3 | Zaadaptowano oryginalną grafikę końcówki latarki PR #70; 40% przezroczystości sylwetek, mgła, pięć cięć/glitch, nominalne 13 Hz | [#42654026061](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42654026061), SHA 8b641fe390c2de99d1859b2ea9130496f52a807e | **PASS** |
| Step 4 | Testy razem: blackout + 3D snop + okrągła mgła + grafika latarki; poprawki zasłaniania ścianami, przezroczystości krawędzi i zachowania dachu | [#42659365244](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42659365244), SHA 64893ab496ec6cc28f0ad4287cf0697c1ce30a34 | **PASS** |
| Step 5 | Powtórzenie gameplay, elevator/grab/respawn i porównawczych testów obciążenia hosta | Pierwszy przebieg #42667212473 miał sukces; **rerun tego samego SHA zakończył się FAILURE** przez konflikt autonomicznego chwytu w fixture. Test naprawiono bez zmiany produkcyjnego kodu; pełny test potwierdzony następnie przez #42677244923 | **PASS po korekcie fixture; historia rerun NIE jest całkowicie zielona** |
| Step 6 | Finalna weryfikacja, inspekcja ZIP-ów i PNG, poprawa izolacji testu chwytu, freeze/handoff | [#42677244923](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42677244923), SHA f1989c8c675357427e2214796e14a5103f1cef01 | **PASS WITH LIMITATIONS** |

### 3.1. Istotne wyniki końcowego Stage 5B

- **20/20** zestawów regresyjnych; **600** klatek smoke; **7** prób wolumetrycznego snopa; **43** kontrole rzeczywistych pikseli fullscreen blackout.
- **59/59** kontroli połączonego renderingu; **22** kontrole jednostkowe końcówki latarki i **21** kontroli rzeczywistych klatek; **33/33** kontrole przejść windy, chwytu i respawnu.
- Pełne archiwum QA: [Actions artifact #13701654092](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42677244923/artifacts/13701654092), 69 PNG, 41 plików logów i **176** okien porównawczego profilu.
- Off-beam próbki blackout były RGB (0,0,0) przy skalach 100%, 67%, 40%; dach zachował jasny profil bez maski.
- Źródła tekstur czterech sektorów mgły i oryginalnego WebP PR #70 były porównane z odpowiednimi Git blobami; obrazy w grze nie zostały zastąpione starszym contour-only.
- Nie stwierdzono powtarzalnej ponad 10% regresji w porównaniach Mesa między Step 4 a Step 5. Jeden wzrost +12,2% przy skali 40% nie powtórzył się w niezależnym przebiegu (wynik przeciwny ok. -11,2%); wniosek **niejednoznaczny**, nie dowód poprawy lub spowolnienia GPU Android.
- Zapisano znane diagnostyki Godot o powielonych nazwach klipów animacji i ostrzeżeniu IK. Nie należy nazywać importu bezostrzeżeniowym.
- W tej fazie **nie zbudowano APK ani AAB**, nie scalono PR do main i nie zmieniono gałęzi źródłowych PR #68/#70.

### 3.2. Reguła graficzna, której nie wolno naruszyć

**FULLSCREEN BLACKOUT na ziemi jest obowiązkowy.** Nie wystarcza winieta, ciemne niebo lub przygaszone otoczenie. Poza efektywnym oświetleniem świat świata ma być czarny, z uzasadnioną widocznością postaci, HUD, oznaczenia bossa i promptów pada. Dach nie stosuje maski naziemnej. Horyzont zombie jest światowo zakotwiczony i podąża za pozycją gracza; grafika na końcu latarki przesuwa się wraz z kierunkiem snopa i jest zasłaniana przez geometrię pierwszego planu.

## 4. Stage 6 — zamrożona kompilacja i kontrola APK

| Parametr | Wartość potwierdzona |
| --- | --- |
| Branch roboczy | build/bijatyka-stage6-final-arm64-20261109 |
| Source branch | integration/bijatyka-stage5b-blackout-fog-20261109 |
| **Właściwy source SHA checkout** | **f1989c8c675357427e2214796e14a5103f1cef01** |
| Commit workflow (nie źródło kodu gry) | ddac53d03946f874cc4307b0849ecd5e31044897 |
| Build Actions | [#42687863317 — SUCCESS](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42687863317) |
| Silnik / renderer | Godot 4.7.2; GL Compatibility |
| Preset / ABI | Android ARM64; wyłącznie arm64-v8a |
| APK | Bijatyka-Stage6-Final-ARM64.apk |
| Rozmiar APK | 66 373 509 bajtów |
| **SHA-256 samego APK** | **4e64243e254c8fb5b2a713dae6ea23be09447833a7ea49572197df5d3d392d4f** |
| Package ID | org.logicsolutionspoland.bijatyka |
| Wersja | versionCode 11; versionName 0.1.11-combat-visuals |
| Android manifest | minSdk 24 (Android 7.0), targetSdk 36 |
| Podpis | poprawny debug signing; APK Signature Scheme v2 oraz v3 PASS |
| Kontrola importowanych tekstur | Cztery zombie_fog_0x.webp i flashlight_tip_zombie_fog.webp obecne wraz ze skompilowanymi .ctex |
| Kontrola zasobów | m.in. blackout/fog/tip shaders, kluczowe skrypty, main scene i player / QTE / grab / Pencil Sketch |
| Testy na dokładnym frozen SHA | **20/20 suites PASS; 6/6 Mesa probes PASS; 600-frame smoke PASS** |
| GitHub artifact | [#13706246072](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42687863317/artifacts/13706246072) (ZIP) |
| ZIP artifact SHA-256 | 6454b60bf4802521176f9367875220ca1fabd5b9b490acbc2d59d7096389de0b — **nie mylić z APK** |
| Wynik na fizycznym telefonie | **NOT TESTED** |

**Różnica konfiguracji:** w pliku game/project.godot wpisano min_sdk=23 i target_sdk=35, lecz finalny AndroidManifest APK raportuje **minSdk=24** i **targetSdk=36**. To rzeczywista różnica wymagająca uwzględnienia przy ewentualnych testach kompatybilności i kolejnym eksporcie; sam podpisany APK przeszedł kontrolę. Starszy telefon Android 7 musi ponadto obsługiwać ARM64.

**Integralność lokalnego pliku:** surowy APK wyodrębniono z aktualnego artefaktu, sprawdzono wielkość 66 373 509 B i ponownie obliczono SHA-256; wynik zgadza się z manifestem builda.

### 4.1. Kontrola funkcji: source, APK, urządzenie

| Funkcja | Testy źródłowe/CI | Wymagane zasoby w APK | Fizyczny Android |
| --- | --- | --- | --- |
| Fullscreen blackout (ground only) | PASS | PASS | NOT TESTED |
| Circular Zombie Fog Horizon (10 m, 96 segmentów, 6 sektorów) | PASS | PASS | NOT TESTED |
| PR #70 flashlight-tip artwork (40%, pięć glitch slices) | PASS | PASS | NOT TESTED |
| Widoczny 3D snop latarki | PASS | PASS | NOT TESTED |
| Character-only Pencil Sketch | PASS | PASS | NOT TESTED |
| Exo Gray, skoki i doskok melee 1,5 m/s | PASS | PASS | NOT TESTED |
| Punch, magic, RAGE | PASS w zestawach regresji | Zachowane zasoby i kod | NOT TESTED |
| AI Director, pojemność 20 zombie, 4 atakujących, limit 7 rigów | PASS w zestawach regresji | Zachowany kod | NOT TESTED |
| Brutal Grab, IK, QTE escape | PASS | PASS | NOT TESTED |
| Wieża, winda, respawn | PASS w fixture / smoke | PASS | NOT TESTED |
| Sterowanie gamepadem | PASS w zestawach regresji | Zachowany input map | NOT TESTED |

**Zastrzeżenie:** PASS kolumny APK oznacza potwierdzenie struktury paczki i zasobów, a nie uruchomienie silnika Godot na telefonie. Przejścia windy w Stage 5B używały przyspieszonego zakończenia w fixture — nie jest to pełen rzeczywisty przejazd.

## 5. Fizyczna akceptacja Android — zadania niewykonane

Podstawowy test powinien odbyć się na telefonie ARM64 z padem. Bez rzeczywistych zapisów obserwacji nie wolno zmienić statusów poniżej na PASS.

1. **Instalacja i start:** podpis, instalacja bez niszczenia danych istniejącego builda, uruchomienie wieży, kamera/HUD/pad.
2. **Dach i winda:** jasny dach bez maski i efektów ziemi; prawdziwy pełny przejazd do poziomu gruntu, bez zawieszenia.
3. **Blackout:** screenshot ziemi; piksele świata poza snopem czarne, ale postać/HUD czytelne; yaw/pitch i ściany nie uszkadzają kompozycji.
4. **Fog i tip:** 10-metrowy animowany okrąg podążający za graczem; 40% sylwetek na końcu latarki, glitch, przesłanianie przez ściany, brak prostokątnej krawędzi.
5. **Sterowanie i walka:** zwykły skok, paraboliczny skok do przodu, punch/doskok, czary, RAGE, AI i wymiana zombie, chwyt/IK/QTE, respawn.
6. **Wydajność i termika:** dach 60 s, pełny przejazd windą, eksploracja 2 min, walka 2 min, ciągła rozgrywka do 5 min i w razie bezpiecznych temperatur dodatkowe 5 min; zanotować FPS, frame-time spikes, ciepło, ostrzeżenia Androida. Przerwać przy nadmiernym nagrzewaniu.

**Brak danych urządzeniowych:** średnie FPS, temperatura, throttling, bateria, długie sesje, poprawność instalacji i całej windy — **NOT TESTED**. Wyników Linux Mesa/OpenGL nie wolno podawać jako rzeczywistych FPS ani danych temperatury Android.

## 6. Ryzyka, defekty i historia napraw

| Obszar | Stwierdzenie | Ocena |
| --- | --- | --- |
| Przestarzały APK Stage 3 | Zbudowany z historycznej bazy, nie zawierał pełnej współczesnej integracji | Rozwiązano wybór źródła w Stage 6; stary pakiet nieaktualny |
| Stage 1 — doskok przy ścianie | Zidentyfikowano brak aktualnego wall-trace; poprawka zweryfikowana na osobnej gałęzi QA | PASS w oddzielnych testach; brak osobnego merge do historycznego main |
| Stage 2 — barierka dachu / kick | Barierka zasłaniała część kadru; klatki mma_kick wyglądały podobnie, ale nie dowodziło to błędu animacji | Historyczne ustalenia na starszym main; ponowna fizyczna weryfikacja potrzebna |
| Stage 5B — Step 4 | Problemy z przesłanianiem, profilem dachu i krawędzią grafiki końcówki latarki | Poprawione i potwierdzone w końcowej matrycy |
| Stage 5B — Step 5 | Niestabilna automatyczna fixture zderzała się z autonomicznym chwytem zombie; drugi przebieg FAILED | Naprawiono izolację fixture, bez zmiany produkcji; finalny Step 6 SUCCESS |
| Stage 6 — SDK | Plik projektu 23/35, wynikowy manifest 24/36 | Potwierdzona rozbieżność konfiguracji, do sprawdzenia zgodności urządzeń |
| Android real device | Brak testu, FPS i pomiarów termicznych | BLOCKER dla pełnej akceptacji Stage 6 i bezwarunkowego Stage 7 |
| Android gamepad + full elevator | Niedostępny fizyczny dowód | NOT TESTED |

**Potwierdzone nowe krytyczne awarie builda Stage 6:** 0. **Nie oznacza to zerowej liczby możliwych błędów urządzeniowych**, ponieważ test telefonu nie nastąpił.

## 7. Bezpieczeństwo Git i następny etap

- **main**: ac12a215d95ce85d982f68b469aea99e75542883, bez zmian podczas Stage 6.
- **Stage 5B integration HEAD**: 2c031f702b01bee3579a9d6856f6459a203b86a7, bez zmian podczas Stage 6.
- **Stage 6 build branch**: build/bijatyka-stage6-final-arm64-20261109, pochodna f1989c8...; w kompilacji dodano wyłącznie dedykowany workflow, bez zmiany gry.
- **Nie scalono żadnego PR**, nie opublikowano release, nie aktualizowano Google Play; Stage 7 nie został uruchomiony.
- Niniejszy raport stanowi **tylko zapis dokumentacyjny** na gałęzi buildowej, a jego dodanie nie powinno wyzwolić kolejnego builda, bo workflow Stage 6 reaguje na zmianę własnego pliku .github/workflows/bijatyka-stage6-final-arm64.yml.

**Stage 7 — gotowość: CONDITIONAL.** Dopiero realna akceptacja telefonu i wyjaśnienie ewentualnych krytycznych usterek pozwolą bezpiecznie rozważyć dalszy osobno autoryzowany merge. **Nie scalać na podstawie samych zielonych testów GitHub.**

## 8. Jednoznaczne pola statusowe

- **STAGE 6 STATUS:** PARTIAL (kompilacja ukończona, akceptacja urządzenia nie).
- **SOURCE INTEGRITY:** PASS.
- **ANDROID ARM64 BUILD:** PASS.
- **APK CONTENT VERIFICATION:** PASS (automatyczne kontrole struktury/zasobów).
- **FULLSCREEN BLACKOUT INCLUDED:** YES (source + APK resource verification; device NOT TESTED).
- **ZOMBIE FOG HORIZON INCLUDED:** YES (source + imported APK textures).
- **FLASHLIGHT-TIP ARTWORK INCLUDED:** YES (oryginalny PR #70 WebP).
- **PHYSICAL ANDROID TESTING:** NOT TESTED.
- **PERFORMANCE AND THERMALS:** NOT TESTED.
- **READY FOR STAGE 7 MAIN MERGE:** CONDITIONAL / NIE wykonywać bez dalszej akceptacji.
- **Finalne testy Stage 6:** 20 PASS / 0 FAIL zestawów, dodatkowo 6 PASS sond Mesa i 600 klatek startu; w końcowym Stage 5B 43/43 blackout, 59/59 combined, 33/33 transitions.
- **main changed:** NO. **PR merged:** NO. **Release published:** NO.

---

**Źródła pierwszorzędne:** [Stan Stage 5B](https://github.com/LogicSolutionsPoland/Bijatyka/blob/integration/bijatyka-stage5b-blackout-fog-20261109/docs/stage5b/STAGE5B_STATE.md), [finalny run Stage 5B](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42677244923), [run budujący Stage 6](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42687863317), [artefakt APK](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42687863317/artifacts/13706246072) oraz wymienione wyżej starsze runy. Część szczegółów Stage 0–3 pochodzi z uprzednich raportów etapów; nowszy Stage 5B nie unieważnia faktu, że starsze testy na main były niepełne.
