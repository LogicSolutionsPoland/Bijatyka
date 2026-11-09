# BIJATYKA — zbiorczy dziennik prac i wyników, 9 listopada 2026

**Repozytorium:** `LogicSolutionsPoland/Bijatyka`  
**Data:** 2026-11-09 (Europe/Warsaw)  
**Silnik i cel:** Godot 4.7.2, GL Compatibility, Android ARM64-v8a, pad  
**Zakres:** historyczne rozpoczęcie weryfikacji Stage 0–2 (8/9 XI), wykonane dzisiaj Stage 3–6, komplet Stage 5B Steps 0–6, diagnostyka i naprawa P1, dwa buildy Androida oraz zgłoszenia fizycznego Androida.  
**Wersja dowodowa:** łączny raport na aktywnej gałęzi P1; nie jest częścią APK.  
**Aktualna ocena:** **AUTOMATED CI PASS / REAL ANDROID ACCEPTANCE FAIL / STAGE 7 BLOCKED.**

> **WAŻNE — ostateczne wyniki telefonu są nadrzędne wobec CI.** Użytkownik po otrzymaniu *nowszego* APK `Bijatyka-Stage6-P1-GrabQTE-ARM64-debug.apk` zgłosił: **„nie ma ani qte ani grab”**. Zatem **naturalny grab = FAIL, QTE = FAIL, akceptacja telefonu = FAIL**, choć symulowane scenariusze Godot/Mesa były zielone. Nie ogłaszać usunięcia usterki. Nie zakładać konkretnej przyczyny braku funkcji bez nowych dowodów urządzeniowych.

## 1. Przegląd głównych etapów Stage 0–6

| Etap | Działania i wyniki | Status / dowód |
| --- | --- | --- |
| **Stage 0 — audyt** | Sprawdzono repozytorium, aktywne mechaniki i rozbieżności gałęzi. Stare `main` (`ac12a215d95ce85d982f68b469aea99e75542883`) nie zawierało całego aktualnego gameplayu; nie można go bezkrytycznie używać jako źródła końcowego APK. | **AUDIT COMPLETE**; źródłowy okres 8–9 XI |
| **Stage 1 — testy mechanik** | Na historycznym `main`: 35/38 automatycznych kontroli PASS, 3 FAIL, część obszarów bez testów. Oddzielnie zweryfikowano poprawkę doskoku do ściany: 13/13 PASS + 600 klatek, gałąź `qa/stage1-wall-doskok-20261108`. | **PARTIAL**, follow-up **PASS**: [#42530999351](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42530999351) |
| **Stage 2 — wizualna weryfikacja** | Na historycznym `main`: 6/6 testów renderingu PASS, 32 zrzuty. Potwierdzono problem barierki na dachu zasłaniającej część kadru; pozostałe sceny/animacje nie były w pełni potwierdzone. | **PARTIAL**; poprzedni etap rozpoczęty 8 XI |
| **Stage 3 — pierwszy APK** | [Actions #42573037879](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42573037879) **SUCCESS**, ale APK zbudowano z przestarzałego `main`. Właściciel zgłosił, że prezentuje stare mechaniki. `Bijatyka-Stage3-Android-ARM64.apk`, SHA-256 `6e034c89967b59c17417d19fd8d65f46f3060a1eccf67005692b55d0c749c200`. | **BUILD PASS / SOURCE NOT ACCEPTABLE** — wycofany jako kandydat końcowy |
| **Stage 4 — integracja nowszej gry** | Utworzono `integration/bijatyka-current-20261109`, HEAD `86ddc8cdb8e883a83f0b8978e7f94f69df27f3b0`. Po nieudanych próbach integracji końcowy [Actions #42584274228](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42584274228) **SUCCESS**. | **PASS w CI**, bez merge do `main` |
| **Stage 5 — integracja funkcji** | Gałąź `integration/bijatyka-stage5-complete-20261109`, SHA `b052aaf876f5cb141547494b62b8c2fdb473e6c4`. [Actions #42623536580](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42623536580) **SUCCESS**: 20/20 zestawów regresji, smoke 600 klatek. **Wciąż brakowało** wymaganego fullscreen blackout oraz adaptacji PR #68/#70. | **CI PASS / INTEGRATION INCOMPLETE**, następnie Stage 5B |
| **Stage 5B — pełna integracja efektów** | Seven Steps 0–6, przywrócono blackout, zaadaptowano fog i grafikę końcówki latarki, wykonano testy Mesa, regresje, pomiary. | **PASS WITH LIMITATIONS** [final #42677244923](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42677244923), bez APK |
| **Stage 6 — pierwszy finalny APK** | Zbudowano aktualniejszy APK na bazie testowanego Stage 5B SHA `f1989c8c675357427e2214796e14a5103f1cef01`. [Actions #42687863317](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42687863317) **SUCCESS**. Po testach telefonu blackout PASS, fog FAIL, tip PARTIAL, brak naturalnych chwytów/QTE. | **BUILD PASS / DEVICE FAIL**; nie uruchamiać Stage 7 |
| **Stage 6 / P1 — naprawa grab/QTE** | Dodatkowa diagnoza, poprawka źródła `enemy.gd`, naturalne testy AI i R3 w CI, dedykowany nowy APK. **Po instalacji właściciel nadal nie obserwuje żadnego grab ani QTE.** | **CI PASS / DEVICE FAIL / DEFECT OPEN**; szczegóły §4 |

**Uwaga chronologiczna:** Stage 0–2 stanowią wcześniejszą część ciągu audytowego 8–9 XI; nie przedstawiamy ich wszystkich jako zrealizowanych od początku do końca 9 listopada. Inne historyczne „Stage” w projektach walki nie są tym samym zakresem.

## 2. Stage 5B — wszystkie kroki 0–6 wykonane 9 listopada

**Gałąź:** `integration/bijatyka-stage5b-blackout-fog-20261109`  
**Dokument źródłowy:** [STAGE5B_STATE.md](https://github.com/LogicSolutionsPoland/Bijatyka/blob/integration/bijatyka-stage5b-blackout-fog-20261109/docs/stage5b/STAGE5B_STATE.md)  
**Końcowy testowany kod:** `f1989c8c675357427e2214796e14a5103f1cef01`.

| Krok | Implementacja / wynik | Sprawdzony run |
| --- | --- | --- |
| **0 — setup i audyt** | **PASS**. Osobna gałąź na bazie Stage 5, audyt otwartych PR #68/#70, plan kontroli oraz dokument stanu. Brak zmian w głównej grze. | Audyt i `STAGE5B_STATE.md` |
| **1 — Fullscreen Blackout** | **PASS**. Przywrócono czarne piksele poza realnym snopem na ziemi; zachowano HUD, widoczność gracza, 3D snop i dach bez maski. 20/20 regresji, 600 klatek, 43 kontrole pikseli. | [#42641061088](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42641061088), SHA `738eb0064a02ba3aca13af31f3829733c695e40e` |
| **2 — Zombie Fog Horizon** | **PASS w CI**. Adaptacja PR #68: promień 10 m, 96 segmentów, sześć sektorów i cztery oryginalne tekstury, podążanie za graczem. Pierwsza próba CI FAIL przez błędne oczekiwanie w teście; po korekcie testu 20/20 i 43 blackout PASS, animacja i skale 100/67/40%. | [#42649851614](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42649851614), SHA `a51ed9c4de20df3126b0865f781b1a9a89ab9051` |
| **3 — grafika na końcu latarki** | **PASS w CI**. Adaptacja PR #70: oryginalne WebP, 40% alfa sylwetek, mgła, pięć poziomych cięć, nominalne 13 Hz; testy źródłowe i autentyczne klatki GL. | [#42654026061](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42654026061), SHA `8b641fe390c2de99d1859b2ea9130496f52a807e` |
| **4 — wspólny rendering** | **PASS w CI**. Test blackout + 3D beam + horizon + tip; naprawiono occlusion przy ścianach, brzeg grafiki i profil dachu. Łącznie **59** kontroli prawdziwych klatek. | [#42659365244](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42659365244), SHA `64893ab496ec6cc28f0ad4287cf0697c1ce30a34` |
| **5 — regresje i profilowanie** | **PASS pierwszej próby**, lecz niezależny **rerun tego samego SHA zakończył się FAIL** wskutek konfliktu z naturalną próbą rezerwacji chwytu w kontrolowanym fixture. 20/20 regresji, 600 klatek, 32 testy przejścia, 176 okien pomiarowych z pierwszego przebiegu. Dalsza naprawa dotyczyła tylko fixture. | [#42667212473](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42667212473), SHA `2cd5329f28f640b7e03d13bc3dd5bd88fa48e098`; wyniki zależą od próby uruchomienia |
| **6 — finalna stabilizacja CI** | **PASS WITH LIMITATIONS**. Poprawiono izolację fixture bez zmian produkcyjnego AI. Ostatecznie 20/20 suites, 600 klatek, 43 blackout, 59 combined, 33 transitions, 69 PNG, 41 logów, 176 próbek porównawczych. Nie wykazano powtarzalnej krytycznej regresji Mesa; brak dowodów mobilnego FPS/termiki. | [#42677244923](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42677244923), SHA `f1989c8c675357427e2214796e14a5103f1cef01`; [QA artifact #13701654092](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42677244923/artifacts/13701654092) |

**Czego Stage 5B NIE udowodnił:** działania na GPU fizycznego Androida, stabilności temperatury, jakości wszystkich póz ani tego, że zombie faktycznie chwytają gracza w normalnej grze mobilnej. Wyraźnie oddzielić od testów symulowanych.

## 3. Stage 6 — pierwsza nowoczesna paczka i akceptacja właściciela

**Zamrożone źródło:** `f1989c8c675357427e2214796e14a5103f1cef01` z Stage 5B.  
**Build:** [GitHub Actions #42687863317](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42687863317), workflow SHA `ddac53d03946f874cc4307b0849ecd5e31044897`, **SUCCESS**.  
**Plik:** `Bijatyka-Stage6-Final-ARM64.apk` (66 373 509 bajtów), SHA-256 `4e64243e254c8fb5b2a713dae6ea23be09447833a7ea49572197df5d3d392d4f`.  
**Artefakt:** [#13706246072](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42687863317/artifacts/13706246072).  
**Kontrole:** Android ARM64-v8a; zasoby fog/blackout/tip, skrypty i podpis **PASS**. Build nie dowodzi pełnej rozgrywki na urządzeniu.

### Fizyczny Android — 7 obszarów zgłoszonych przez właściciela

| Obszar | Wynik | Faktycznie zgłoszone |
| --- | --- | --- |
| Uruchomienie i dach | **PASS** | Działa |
| Pełny przejazd windą | **PASS** | Działa |
| Fullscreen Blackout | **PASS** | Działa — wymagany element, chronić |
| Zombie Fog Horizon | **FAIL** | Problem istnieje; właściciel odłożył naprawę, bez doprecyzowania objawu |
| Grafika końcówki latarki | **PARTIAL** | Wygląd brzydki, nie spełnia oczekiwań |
| Chwyty zombie / QTE | **FAIL** | Właściciel doprecyzował: nie ma żadnego rzeczywistego chwytania, a QTE nie występuje |
| Wydajność / temperatura | **PASS — subiektywnie** | Brak liczbowego FPS, temperatury i czasu sesji; nie utożsamiać z testem laboratoryjnym |

**Zbiorczo: 4 PASS, 1 PARTIAL, 2 FAIL — całkowita akceptacja urządzenia FAIL.** Pierwotny opis chwytów sugerował brak animacji; późniejsze sprostowanie jednoznacznie potwierdziło brak samego zdarzenia chwytu.

### Zabezpieczenia

- **Fullscreen Blackout ma pozostać**. Nie przywracać starej, wadliwej wersji grafiki.
- **Zombie Fog Horizon — odłożony** przez właściciela, nie mieszać z P1.
- Efekt końca latarki pozostaje artystycznie **PARTIAL** i poza P1.
- Nie wdrażać Stage 7 i nie scalać na podstawie zielonego CI.

## 4. Stage 6 / P1 — przebieg diagnostyki, naprawy i drugiego APK

**Gałąź:** `fix/bijatyka-stage6-grab-qte-android-20261109` (od testowanego Stage 5B `f1989c8...`).  
**Dokument diagnostyczny:** [STAGE6_P1_GRAB_QTE_DIAGNOSIS.md](https://github.com/LogicSolutionsPoland/Bijatyka/blob/fix/bijatyka-stage6-grab-qte-android-20261109/docs/stage6/STAGE6_P1_GRAB_QTE_DIAGNOSIS.md).

1. **Audyt kontrolowanego QTE:** [#42696826410](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42696826410) **SUCCESS**, pięć suite, HUD i symulowane R3 działały w testach sterowanych. Tego nie można było uznać za naturalną rozgrywkę.
2. **Rzeczywisty test produkcyjnego AI ujawnia usterkę:** [#42701499716](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42701499716) **FAIL** — 18 ataków, 12 prób chwytu, **0 uruchomień QTE**. Odmowy: `visual_contact_unreachable`, `contact_failed`.
3. **Potwierdzono przyczynę geometrii w tym scenariuszu:** [#42703104494](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42703104494). Efektywny zasięg kończyny zombie ~0,525 m, cel na widocznym przedramieniu Exo Gray typowo ~0,669–1,005 m od barku. Pierwsza korekta podejścia [#42702534923](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42702534923) nadal **FAIL**.
4. **Minimalna poprawka w `game/scripts/enemy.gd`:** commit `fdb3fe055b6d5b06c2f0bb75ac90cdcf987ee833` — zombie naturalnie zbliża się od strony wybranego przedramienia w trakcie istniejącego windup; bez teleportacji, bez osłabiania zasięgu IK, kolizji, ownership slotu i warunków QTE. [#42703726486](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42703726486) **SUCCESS** w naturalnym teście hosta.
5. **Dalszy test ścieżki R3 i renderingu:** [#42704177652](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42704177652), [#42704672958](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42704672958), oba **SUCCESS**. Produkcyjna AI w Mesa rozpoczęła rzeczywisty kontakt i QTE; test przyjął trzy odrębne zdarzenia R3, wykonał ucieczkę i recovery. Zapisano siedem realnych klatek: approach, windup, hand-reaching, contact-qte, restrained, escape, recovery; Blackout PASS. Nie każda próba chwytu ma się udać — dwa odrzucone windup były poza dopuszczalnym zasięgiem.
6. **Nowy P1 debug APK (jeden build):** [Actions #42707639776](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42707639776) **SUCCESS**, źródło/workflow SHA `2949e9873ea64945ad508823b1878b7639a8aee8`. Workflow potwierdził identyczność plików gry z poprzednim zielonym CI `e2bb1097...`, obecność poprawki `enemy.gd`, 5 suites, naturalne grab/QTE/3 R3, skoki/AI, GL/blackout, 7 klatek, eksport i integralność paczki. **Brak nowych zmian w gameplayu podczas builda.**
7. **Drugi plik APK:** `Bijatyka-Stage6-P1-GrabQTE-ARM64-debug.apk`, SHA-256 **`ec20129f701f12b97361f28bfec07e27682affebdd469eedf770a39ef9b08c1a`**. Artefakt [#13715370279](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42707639776/artifacts/13715370279), ZIP zawiera **jeden APK**, podpis debug/manifest/ARM64/zasoby **PASS**.
8. **Właściciel przetestował dostarczony P1 APK na Androidzie i zgłosił:** **„nie ma ani qte ani grab”**. Ostateczny wynik na fizycznym urządzeniu: **naturalny chwyt FAIL, QTE FAIL, R3 escape NOT TESTABLE, Android acceptance FAIL**. Wpis diagnostyczny zapisano commitem `888eaad246a1b07724099199fb961be10efcfff4`. Dokładna przyczyna rozbieżności między hostowym testem a telefonem **pozostaje niepotwierdzona**; brak załączonych logów wideo czy niezależnej sumy kontrolnej z telefonu.

**Znana niedoskonałość prezentacji:** windup używa animacji pochodzącej od ciosu, a nie odrębnej dopracowanej animacji dwuosobowego chwytu. To **nie wyjaśnia samo w sobie** braku naturalnego chwycenia i QTE na Androidzie. Żadna dalsza zmiana mechanik nie została zatwierdzona w ramach tego dziennego zapisu.

## 5. Macierz aktualnych statusów (stan końcowy 9 XI)

| Element | CI / źródło | Fizyczny Android / wynik właściciela |
| --- | --- | --- |
| Uruchomienie, dach, winda (pierwszy Stage 6 APK) | **PASS** w dostępnych testach | **PASS** |
| Fullscreen Blackout | **PASS** (43+59 testów renderu) | **PASS** |
| Okrągły Zombie Fog Horizon | **PASS** na Mesa | **FAIL — odłożone** |
| Grafika końcówki latarki | **PASS** na Mesa | **PARTIAL — nieakceptowalny wygląd** |
| Chwyty naturalne (nowszy P1 APK) | **PASS** w scenariuszu CI po poprawce | **FAIL — brak zdarzeń** |
| QTE HUD i trzy R3 | **PASS** w teście hostowym | **FAIL — QTE się nie pojawia; R3 nie do przetestowania** |
| Wydajność/temperatura | Hostowa próba, **bez wiarygodnego mobile FPS** | Pierwszy APK: ocena PASS bez pomiarów; nowszy P1 APK: brak porównawczych danych |
| Bezpieczeństwo źródeł | Wyodrębnione SHAs i bramki buildów **PASS** | Brak niezależnej kontroli SHA-256 pliku zainstalowanego na telefonie |

**Wniosek końcowy:** Stage 5B zakończony dla hostowej automatycznej integracji. Stage 6 i P1 **NIEzaakceptowane urządzeniowo**, gdyż brak naturalnych chwytów i QTE w najnowszym P1 APK; Zombie Fog Horizon nadal FAIL (naprawa odłożona), tip PARTIAL. Nie łączyć „CI PASS” z „działa na telefonie”.

## 6. Zasady kontynuacji / zachowanie zmian

- **Nie zmieniono `main`** (zweryfikowany HEAD `ac12a215d95ce85d982f68b469aea99e75542883` na moment tworzenia raportu); brak merge i release.
- **Nie zmieniać źródłowej gałęzi Stage 5B**, jej prace 0–6 są zakończone; dokładny zielony SHA `f1989c8...`.
- **Zachować Fullscreen Blackout** w postaci potwierdzonej na telefonie; nie modyfikować fog lub tip podczas naprawy P1.
- **Nie startować Stage 7** przed zakończeniem akceptacji urządzenia i odrębną zgodą właściciela.
- **Nie zmieniać żadnych programów bez wyraźnego pozwolenia.** Ten raport to wyłącznie dokumentacja, bez modyfikacji `game/**`, shaderów, workflow, APK, gałęzi Stage 5B i `main`.
- Przyszła diagnostyka naturalnego chwytu powinna zbadać rzeczywiste zdarzenia w produkcyjnej scenie na Androidzie, sygnały `grab_windup_started` i `grab_qte_started`, odmowy kontaktu, zachowanie AI slotów i przesyłanie zdarzeń HUD. Są to **propozycje diagnostyczne**, nie zatwierdzenie zmian mechanik.
- Dwa historyczne nowoczesne buildy Stage 6 i Stage 6/P1 pozostają osobnymi artefaktami; w ramach *niniejszego raportu* nie uruchamia się ani nie generuje kolejnego APK.

## 7. Referencje — źródła dowodowe

- [Raport Stage 0–6 z wcześniejszego builda](https://github.com/LogicSolutionsPoland/Bijatyka/blob/build/bijatyka-stage6-final-arm64-20261109/docs/stage6/BIJATYKA_RAPORT_ZBIORCZY_STAGE_0-6_2026-11-09.md) — historyczny punkt odniesienia, wcześniejszy od najnowszego testu P1.
- [Stan Stage 5B Steps 0–6](https://github.com/LogicSolutionsPoland/Bijatyka/blob/integration/bijatyka-stage5b-blackout-fog-20261109/docs/stage5b/STAGE5B_STATE.md).
- [Historia diagnozy, naprawy i Android FAIL P1](https://github.com/LogicSolutionsPoland/Bijatyka/blob/fix/bijatyka-stage6-grab-qte-android-20261109/docs/stage6/STAGE6_P1_GRAB_QTE_DIAGNOSIS.md).
- [Stage 5B final CI #42677244923](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42677244923).
- [Stage 6 baseline APK #42687863317](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42687863317).
- [Stage 6/P1 newer APK #42707639776](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42707639776).

**ZAPIS KOŃCOWY: Stage 5B CI PASS / Stage 6 APK BUILD PASS / Stage 6 P1 APK BUILD PASS / NATURAL GRAB ANDROID FAIL / QTE ANDROID FAIL / FULLSCREEN BLACKOUT ANDROID PASS / ZOMBIE FOG ANDROID FAIL (DEFERRED) / TIP ARTWORK ANDROID PARTIAL / MAIN UNCHANGED / STAGE 7 NOT STARTED.**
