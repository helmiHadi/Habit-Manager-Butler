**Butler 🛡️**

**Butler** is a cross-platform digital well-being and productivity management application designed to help users gain control over their digital habits, monitor screen time, block distracting applications, and foster healthier daily routines.

---

## 🚀 Key Features

- **Real-Time Screen Time Tracking**: Precisely track screen time duration and usage statistics across individual applications.
- **Application Blocker & Time Limits**: Set daily usage quotas and temporarily block access to distracting applications once limits are reached.
- **Focus Mode & Scheduled Sessions**: Create automated focus schedules (e.g., work hours, study sessions) to minimize digital distractions.
- **Detailed Usage Analytics**: Clear visualization of usage patterns through daily, weekly, and monthly activity charts.
- **Secure Cloud Sync**: Efficient data synchronization and storage utilizing encrypted cloud backend services.

---

## 🛠️ Tech Stack & Architecture

Butler is built on a full-stack Dart architecture ensuring high performance and seamless client-server communication:

- **Frontend**: [Flutter](https://flutter.dev/) (Cross-Platform Mobile Application)
- **Backend**: [Serverpod](https://serverpod.dev/) (App backend framework written in Dart)
- **Database**: PostgreSQL
- **Deployment & Hosting**: Google Cloud Run & Docker Containers

---

## 📂 Project Structure

This repository follows standard Serverpod multi-package architecture:

```text
butler/
├── butler_client/       # Auto-generated client package for API communication
├── butler_flutter/      # Flutter user interface, state management, and client logic
└── butler_server/       # Serverpod backend endpoints, ORM models, and database migrations
