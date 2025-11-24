# LEGO 온라인 데이터 수집 및 DRIP 분석

전북대학교 데이터시각화 DRIP 프로젝트 – 레고(LEGO) 온라인 데이터 수집 및 분석.

## 👥 팀 정보
- 팀명: 분석의 대가
- 팀원: 202019668 지동원, 202217185 오진관, 202313587 최정
- 기간: 2025.11.12 ~ 2025.11.24

## 📂 폴더 구조

- `analysis/`
  - `final/` : 최종 분석 코드, DRIP용 R Markdown 파일, 최종 시각화 코드
  - `archive/` : 탐색 과정에서 사용한 임시/실험용 코드 (시행착오 기록)
- `crawler/`
  - `final/` : 최종 크롤링 코드 (재실행 가능한 버전)
  - `archive/` : 크롤링 테스트 코드, 오류 수정 전 버전 등
- `data_raw/` : 사이트에서 수집한 원본 데이터 (CSV 등)
- `data_clean/` : 전처리 후 분석에 사용한 최종 데이터
- `docs/` : 최종 보고서 HTML, 발표 자료(PPT, PDF), 참고 이미지

## 🔧 실행 환경

- R version: 4.1.2
- 주요 패키지: `tidyverse`, `rvest`, `RSelenium`, `chromote`, `janitor`, `ggplot2` 등

## 🎯 프로젝트 목표 요약

- LEGO 공식 사이트에서 전 제품 데이터를 수집하고,
- DRIP 프레임워크(Data–Reasoning–Insight–Problem)에 따라 분석하여
- 레고의 가격 전략, 연령대별 제품 구성, 성인 타깃 전략 등을 탐색한다.
