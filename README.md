# BMT - Hiking Tracker 🏔️

**BMT (Hiking Tracker)**는 사용자의 등산 및 야외 활동 위치를 실시간으로 기록하고 관리할 수 있는 모바일 애플리케이션입니다. Flutter 프레임워크를 기반으로 개발되었으며, 백그라운드 환경에서도 안정적으로 사용자의 이동 경로를 추적 및 기록합니다.

## ✨ 주요 기능

- **실시간 경로 추적**: `geolocator`와 `flutter_map`을 활용하여 사용자의 현재 위치와 이동 경로를 지도 상에 실시간으로 표시합니다.
- **백그라운드 데이터 수집**: `flutter_foreground_task`를 적용하여 앱이 백그라운드 상태이거나 기기 화면이 꺼진 상태에서도 끊김 없이 운동 기록을 측정하고 경로를 추적합니다.
- **데이터 자동 기록**: 사용자의 운동 시간과 경로 데이터를 `sqflite` 로컬 데이터베이스에 안전하게 자동 보관합니다.
- **프로필 & 사진 기록**: `image_picker`를 통해 갤러리 또는 카메라로 프로필 사진을 편하게 등록하고 관리할 수 있습니다.
- **푸시 상태 알림**: 운동 진행 상황 및 추적 상태를 `flutter_local_notifications`를 통해 즉각적으로 알려줍니다.
- **편의 및 보안 기능**: 생체 인증과 ML Kit를 통한 카메라 카드 스캔 기능(예정/지원) 등을 고려한 안전한 데이터 및 인증 흐름을 제공합니다.

## 🚀 최근 업데이트 내역

### v1.0.2
- **기록 상세 페이지 UI/UX 개편 및 갤러리 추가**: 사진 목록을 전체화면 스와이프 갤러리로 고도화하고 탭 시 메모/코멘트를 오버레이로 표시합니다.
- **통계 고도화**: 평균 속도, 누적 등반 고도, 최고 출현 고도를 기록 상세 통계 그리드에 추가했습니다.
- **초기 지도 중앙 자동 정렬**: 기록 모드 진입 및 등산 시작 시 사용자 위치 기준으로 지도 화면을 즉각 이동합니다.
- **배터리 최적화 모드**: 3초 간격의 '실시간' 모드와 10초 간격의 '절약' 모드를 추가하여 위치 데이터 수집 주기를 최적화했습니다.
- **운동 대시보드 및 맞춤 마커 개선**: 시간, 거리, 속도 등 진행 상황에 Glassmorphism UI를 적용하고, 출발(S) & 도착(E)를 커스텀 그래픽 핀으로 표시하며, 실제 촬영 이미지가 지도에 동그란 핀 마커로 노출되도록 개선했습니다.

## 🛠 기술 스택

- **프레임워크**: Flutter (Dart)
- **지도/위치**: `flutter_map`, `flutter_map_marker_cluster`, `geolocator`, `latlong2`
- **상태 관리/아키텍처**: `provider`
- **백그라운드 서비스**: `flutter_foreground_task`
- **로컬 저장소 (DB)**: `sqflite`, `shared_preferences`, `path_provider`
- **기기 제어 & 권한**: `image_picker`, `flutter_local_notifications`
- **UI 및 폰트**: `google_fonts` (Noto Sans KR 등), `cupertino_icons`

## 📱 빌드 및 실행 방법

1. **패키지 설치**
   ```bash
   cd hiking_tracker
   flutter pub get
   ```
2. **앱 실행 (Android / iOS)**
   ```bash
   flutter run
   ```

## 📝 관리 및 유지보수
본 프로젝트는 **KimJH-Developer** (github.com/kimjh-developer/bmt) 에 의해 형상 관리가 진행되며 지속적으로 앱 품질을 개선하고 있습니다.
