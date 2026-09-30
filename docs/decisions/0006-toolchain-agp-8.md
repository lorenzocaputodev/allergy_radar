# 0006. Toolchain Android sulla linea AGP 8.x

- Stato: Accettata
- Data: 2026-09-30

## Contesto

Il template di Flutter 3.47.5 crea progetti con AGP 9.1 e Kotlin 2.4. Con JDK 21 la build falliva per target JVM
diversi tra Java (17) e Kotlin (21). My Tracking App compila stabilmente con AGP 8.13.2.

## Decisione

Stessa toolchain di My Tracking App: Gradle 8.14.5, AGP 8.13.2, Kotlin 2.2.21, `jvmTarget` 17, JDK 21, daemon
Gradle a 2 GB. Dependabot non aggiorna Gradle, AGP e Kotlin.

## Conseguenze

- Build riproducibile sulla stessa macchina e in CI.
- Il passaggio ad AGP 9 va fatto a mano, per entrambi i progetti, con un nuovo ADR.
