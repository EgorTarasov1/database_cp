# Game Portal DB — Курсовой проект по базам данных

## Требования

- Docker и Docker Compose (рекомендуется)
- Python 3.12 и pip (если планируете запускать приложение локально без контейнера)

## Настройка

1. Склонируйте репозиторий
   ```bash
   git clone https://github.com/EgorTarasov1/database_cp
   cd database_cp
   ```
   
2. Создайте в папка проекта файл .env и заполните его данными вашего подключения, например:
   ```bash
   POSTGRES_DB=game_portal_db
   POSTGRES_USER=postgres
   POSTGRES_PASSWORD=your_strong_password
   DATABASE_URL=postgresql://postgres:your_strong_password@localhost:5445/game_portal_db
   ```
   
3. Для запуска в docker, находясь в корневой папке проекта выполните команду:
   ```bash
   docker compose up -d --build api
   ```
   После запуска контейнера проект будет доступен по адресу `http://localhost:8000/docs`

4. Для локального запуска, находясь в корневой папке проекта выполните команду:
   ```bash
   docker compose up -d postgres
   ```
   После запуска базы данных установите необходимые зависимости приложения:
   ```bash
   cd backend
   pip install -r requirements.txt
   ```  
   Наконец, вернитесь в корневую папку и выполните запуск сервера:
   ```bash
   cd ../
   uvicorn backend.main:app --reload
   ```  
   
   