import psycopg2
from faker import Faker
from tqdm import tqdm
import random
from datetime import date, timedelta
import logging
from dotenv import load_dotenv
from urllib.parse import urlparse
import os

fake = Faker('ru_RU')

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")

print(DATABASE_URL)
if not DATABASE_URL:
    raise ValueError("DATABASE_URL не задан!")

parsed = urlparse(DATABASE_URL)

DB_PARAMS = {
    'host': parsed.hostname,
    'port': parsed.port or 5432,
    'database': parsed.path[1:],
    'user': parsed.username,
    'password': parsed.password
}

NUM_USERS = 1000
NUM_COMPANIES = 800
NUM_GENRES = 35
NUM_PLATFORMS = 25
NUM_GAMES = 8000
NUM_PROGRESS = 10000
NUM_REVIEWS = 8000


def connect_db():
    return psycopg2.connect(**DB_PARAMS)


def clear_tables():
    conn = connect_db()
    cur = conn.cursor()
    tables = [
        'reviews', 'user_game_progress', 'game_genres', 'game_platforms',
        'games', 'platforms', 'genres', 'companies', 'users'
    ]
    for table in tables:
        cur.execute(f"DELETE FROM {table} CASCADE;")
    conn.commit()
    cur.close()
    conn.close()
    print("Все таблицы очищены.")


def populate_users():
    conn = connect_db()
    cur = conn.cursor()
    inserted = 0
    for _ in tqdm(range(NUM_USERS * 2), desc="Пользователи"):
        if inserted >= NUM_USERS:
            break
        username = fake.user_name()[:50]
        email = fake.email()
        password_hash = fake.password(length=20)
        bio = fake.sentence(nb_words=15) if random.random() > 0.3 else None
        try:
            cur.execute("""
                INSERT INTO users (username, email, password_hash, bio)
                VALUES (%s, %s, %s, %s)
            """, (username, email, password_hash, bio))
            conn.commit()
            inserted += 1
        except psycopg2.IntegrityError:
            conn.rollback()
    cur.close()
    conn.close()
    print(f"Успешно добавлено {inserted} пользователей.")


def populate_companies():
    conn = connect_db()
    cur = conn.cursor()
    for _ in tqdm(range(NUM_COMPANIES), desc="Компании"):
        name = fake.company()[:100]
        year = random.randint(1901, date.today().year)
        country = fake.country()[:50]
        website = fake.url()
        cur.execute("""
            INSERT INTO companies (name, founded_year, country, website)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (name) DO NOTHING
        """, (name, year, country, website))
    conn.commit()
    cur.close()
    conn.close()
    print(f"Добавлено до {NUM_COMPANIES} компаний.")


def populate_genres():
    conn = connect_db()
    cur = conn.cursor()
    genres = [
                 "Action", "Adventure", "RPG", "Shooter", "Strategy", "Simulation",
                 "Sports", "Puzzle", "Racing", "Horror", "Platformer", "Fighting",
                 "MMO", "Indie", "Open World", "Survival", "Stealth", "Metroidvania"
             ] + [fake.word().capitalize() for _ in range(NUM_GENRES - 18)]
    for name in tqdm(genres[:NUM_GENRES], desc="Жанры"):
        desc = fake.sentence(nb_words=10)
        cur.execute("""
            INSERT INTO genres (name, description)
            VALUES (%s, %s)
            ON CONFLICT (name) DO NOTHING
        """, (name, desc))
    conn.commit()
    cur.close()
    conn.close()
    print(f"Добавлено {NUM_GENRES} жанров.")


def populate_platforms():
    conn = connect_db()
    cur = conn.cursor()
    platforms = ["PC", "PlayStation 5", "Xbox Series X", "Nintendo Switch", "PS4", "Xbox One"]
    for name in tqdm(platforms + [fake.word().capitalize() for _ in range(NUM_PLATFORMS - 6)], desc="Платформы"):
        year = random.randint(1990, 2025)
        manufacturer = fake.company()
        cur.execute("""
            INSERT INTO platforms (name, manufacturer, release_year, is_current_gen)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (name) DO NOTHING
        """, (name, manufacturer, year, year >= 2020))
    conn.commit()
    cur.close()
    conn.close()
    print(f"Добавлено {NUM_PLATFORMS} платформ.")


def populate_games():
    conn = connect_db()
    cur = conn.cursor()
    cur.execute("SELECT company_id FROM companies")
    companies = [row[0] for row in cur.fetchall()]
    if not companies:
        raise ValueError("Нет компаний в базе! Сначала заполните companies.")

    inserted = 0
    for _ in tqdm(range(NUM_GAMES * 2), desc="Игры"):  # *2 для компенсации конфликтов по title
        if inserted >= NUM_GAMES:
            break
        title = fake.catch_phrase()[:100]
        desc = fake.text(max_nb_chars=500)
        release = fake.date_between(start_date=date(1990, 1, 1), end_date=date.today())
        company_id = random.choice(companies)

        try:
            cur.execute("""
                INSERT INTO games (title, description, release_date, company_id)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (title) DO NOTHING
            """, (title, desc, release, company_id))
            if cur.rowcount > 0:
                inserted += 1
            conn.commit()
        except psycopg2.IntegrityError as e:
            conn.rollback()
            continue

    cur.close()
    conn.close()
    print(f"Успешно добавлено {inserted} игр.")


def populate_progress_and_reviews():
    conn = connect_db()
    cur = conn.cursor()
    cur.execute("SELECT user_id FROM users")
    users = [row[0] for row in cur.fetchall()]
    cur.execute("SELECT game_id FROM games")
    games = [row[0] for row in cur.fetchall()]
    if not users or not games:
        print("Нет пользователей или игр — пропускаем прогресс и отзывы.")
        return

    statuses = ['Playing', 'Completed', 'Planned', 'Dropped']

    for _ in tqdm(range(NUM_PROGRESS), desc="Прогресс"):
        user_id = random.choice(users)
        game_id = random.choice(games)
        status = random.choice(statuses)
        hours = random.randint(0, 500)
        cur.execute("""
            INSERT INTO user_game_progress (user_id, game_id, status, hours_played)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (user_id, game_id) DO NOTHING
        """, (user_id, game_id, status, hours))

    for _ in tqdm(range(NUM_REVIEWS), desc="Отзывы"):
        user_id = random.choice(users)
        game_id = random.choice(games)
        rating = random.randint(1, 10)
        text = fake.paragraph(nb_sentences=5)
        approved = random.random() > 0.1  # 90% одобрены
        cur.execute("""
            INSERT INTO reviews (user_id, game_id, rating, review_text, is_approved)
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (user_id, game_id) DO NOTHING
        """, (user_id, game_id, rating, text, approved))

    conn.commit()
    cur.close()
    conn.close()
    print(f"Добавлено прогрессов и отзывов.")


def populate_game_connections():
    conn = connect_db()
    cur = conn.cursor()
    cur.execute("SELECT game_id FROM games")
    games = [row[0] for row in cur.fetchall()]
    cur.execute("SELECT genre_id FROM genres")
    genres = [row[0] for row in cur.fetchall()]
    cur.execute("SELECT platform_id FROM platforms")
    platforms = [row[0] for row in cur.fetchall()]

    for game_id in tqdm(games, desc="game_genres"):
        num_genres = random.randint(1, min(5, len(genres)))
        chosen_genres = random.sample(genres, num_genres)
        for genre_id in chosen_genres:
            cur.execute("""
                INSERT INTO game_genres (game_id, genre_id)
                VALUES (%s, %s)
                ON CONFLICT DO NOTHING
            """, (game_id, genre_id))

    for game_id in tqdm(games, desc="game_platforms"):
        num_platforms = random.randint(1, min(4, len(platforms)))
        chosen_platforms = random.sample(platforms, num_platforms)
        for platform_id in chosen_platforms:
            cur.execute("""
                INSERT INTO game_platforms (game_id, platform_id)
                VALUES (%s, %s)
                ON CONFLICT DO NOTHING
            """, (game_id, platform_id))

    conn.commit()
    cur.close()
    conn.close()
    print("Связи game_genres и game_platforms заполнены.")


def populate_user_profiles():
    conn = connect_db()
    cur = conn.cursor()
    cur.execute("SELECT user_id FROM users")
    users = [row[0] for row in cur.fetchall()]

    inserted = 0
    for user_id in tqdm(users, desc="User Profiles"):
        avatar_url = fake.image_url(width=200, height=200) if random.random() > 0.7 else None
        birth_date = fake.date_of_birth(minimum_age=13, maximum_age=80) if random.random() > 0.6 else None
        country = fake.country()[:50] if random.random() > 0.4 else None

        try:
            cur.execute("""
                INSERT INTO user_profiles (user_id, avatar_url, birth_date, country)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (user_id) DO NOTHING
            """, (user_id, avatar_url, birth_date, country))
            if cur.rowcount > 0:
                inserted += 1
        except psycopg2.Error as e:
            conn.rollback()
            print(f"Ошибка при вставке профиля {user_id}: {e}")
            continue

    conn.commit()
    cur.close()
    conn.close()
    print(f"Добавлено {inserted} профилей пользователей.")


def disable_triggers():
    conn = connect_db()
    cur = conn.cursor()
    tables = ['reviews', 'user_game_progress', 'games', 'users']
    for table in tables:
        cur.execute(f"ALTER TABLE {table} DISABLE TRIGGER ALL;")
    conn.commit()
    print("Триггеры отключены")


def enable_triggers():
    conn = connect_db()
    cur = conn.cursor()
    tables = ['reviews', 'user_game_progress', 'games', 'users']
    for table in tables:
        cur.execute(f"ALTER TABLE {table} ENABLE TRIGGER ALL;")
    conn.commit()
    print("Триггеры включены")


logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
print("Начинаю наполнение базы данными...")
disable_triggers()
clear_tables()
populate_users()
populate_user_profiles()
populate_companies()
populate_genres()
populate_platforms()
populate_games()
populate_progress_and_reviews()
populate_game_connections()
enable_triggers()
print("Наполнение завершено! База готова к демонстрации.")