create table users (
    user_id serial primary key,
    username varchar(50) not null unique,
    email varchar(100) not null unique check (email ~* '^[a-za-z0-9._+%-]+@[a-za-z0-9.-]+[.][a-za-z]+$'),
    password_hash varchar(255) not null,
    registration_date date not null default current_date,
    is_active boolean not null default true,
    bio text,
    total_hours integer default 0
);

create table companies (
    company_id serial primary key,
    name varchar(100) not null unique,
    founded_year int check (founded_year > 1900 and founded_year <= extract(year from current_date)),
    country varchar(50),
    website varchar(255),
    created_at timestamp not null default current_timestamp
);

create table genres (
    genre_id serial primary key,
    name varchar(50) not null unique,
    description text,
    created_at timestamp not null default current_timestamp
);

create table platforms (
    platform_id serial primary key,
    name varchar(100) not null unique,
    manufacturer varchar(100),
    release_year int check (release_year > 1900),
    is_current_gen boolean not null default false,
    created_at timestamp not null default current_timestamp
);

create table games (
    game_id serial primary key,
    title varchar(100) not null unique,
    description text not null,
    release_date date not null,
    company_id int not null,
    created_at timestamp not null default current_timestamp,
    average_rating numeric(3,2) default 0.0,
    review_count integer default 0,
    foreign key (company_id) references companies(company_id) on delete restrict on update cascade
);

create table game_genres (
    game_id int not null,
    genre_id int not null,
    primary key (game_id, genre_id),
    foreign key (game_id) references games(game_id) on delete cascade on update cascade,
    foreign key (genre_id) references genres(genre_id) on delete cascade on update cascade
);

create table game_platforms (
    game_id int not null,
    platform_id int not null,
    primary key (game_id, platform_id),
    foreign key (game_id) references games(game_id) on delete cascade on update cascade,
    foreign key (platform_id) references platforms(platform_id) on delete cascade on update cascade
);

create table user_game_progress (
    progress_id serial primary key,
    user_id int not null,
    game_id int not null,
    status varchar(20) not null check (status in ('Playing', 'Completed', 'Planned', 'Dropped')),
    hours_played int default 0 check (hours_played >= 0),
    last_played timestamp,
    last_updated timestamp not null default current_timestamp,
    foreign key (user_id) references users(user_id) on delete cascade on update cascade,
    foreign key (game_id) references games(game_id) on delete cascade on update cascade,
    unique (user_id, game_id)
);

create table reviews (
    review_id serial primary key,
    user_id int not null,
    game_id int not null,
    rating int not null check (rating between 1 and 10),
    review_text text not null,
    created_at timestamp not null default current_timestamp,
    is_approved boolean not null default true,
    foreign key (user_id) references users(user_id) on delete cascade on update cascade,
    foreign key (game_id) references games(game_id) on delete cascade on update cascade,
    unique (user_id, game_id)
);

create table user_profiles (
    user_id int primary key,
    avatar_url varchar(255),
    birth_date date,
    country varchar(50),
    about text,
    foreign key (user_id) references users(user_id) on delete cascade
);

create table audit_logs (
    log_id serial primary key,
    table_name varchar(50) not null,
    operation char(7) not null check (operation in ('INSERT', 'UPDATE', 'DELETE')),
    user_id varchar(50) not null default current_user,
    record_id int,
    old_data jsonb,
    new_data jsonb,
    changed_at timestamp not null default current_timestamp
);


create or replace function audit_trigger_func() returns trigger as $$
declare
    rec_id integer;
begin
    if tg_relname = 'users' then
        rec_id := coalesce(new.user_id, old.user_id);
    elsif tg_relname = 'games' then
        rec_id := coalesce(new.game_id, old.game_id);
    elsif tg_relname = 'user_game_progress' then
        rec_id := coalesce(new.progress_id, old.progress_id);
    elsif tg_relname = 'reviews' then
        rec_id := coalesce(new.review_id, old.review_id);
    else
        rec_id := null;
    end if;

    insert into audit_logs (table_name, operation, user_id, record_id, old_data, new_data, changed_at)
    values (
        tg_relname,
        tg_op,
        current_user,
        rec_id,
        row_to_json(old)::jsonb,
        row_to_json(new)::jsonb,
        current_timestamp
    );

    return null;
end;
$$ language plpgsql;

create trigger audit_users after insert or update or delete on users for each row execute function audit_trigger_func();
create trigger audit_users after insert or update or delete on games for each row execute function audit_trigger_func();
create trigger audit_progress after insert or update or delete on user_game_progress for each row execute function audit_trigger_func();
create trigger audit_reviews after insert or update or delete on reviews for each row execute function audit_trigger_func();



create or replace function update_game_aggregates() returns trigger as $$
declare
    gid integer;
begin
    if tg_op = 'DELETE' then
        gid := old.game_id;
    else
        gid := new.game_id;
    end if;
    update games set
        average_rating = coalesce((select avg(rating) from reviews where game_id = gid and is_approved = true), 0.0),
        review_count = (select count(*) from reviews where game_id = gid and is_approved = true)
    where game_id = gid;
    return null;
end;
$$ language plpgsql;

create trigger trig_update_game_aggregates
after insert or update or delete on reviews
for each row execute function update_game_aggregates();

create or replace function update_user_total_hours() returns trigger as $$
declare
    uid integer;
begin
    if tg_op = 'DELETE' then
        uid := old.user_id;
    else
        uid := new.user_id;
    end if;
    update users set
        total_hours = coalesce((select sum(hours_played) from user_game_progress where user_id = uid), 0)
    where user_id = uid;
    return null;
end;
$$ language plpgsql;

create trigger trig_update_user_total_hours
after insert or update or delete on user_game_progress
for each row execute function update_user_total_hours();



create or replace function get_game_rating(gameid int) returns numeric as $$
select coalesce(avg(rating), 0) from reviews where game_id = gameid and is_approved = true;
$$ language sql;

create or replace function get_user_total_hours(userid int) returns int as $$
select coalesce(sum(hours_played), 0) from user_game_progress where user_id = userid;
$$ language sql;



create or replace function get_top_players_by_genre(genre_name varchar) returns table(
    user_id int,
    username varchar,
    total_hours int
) as $$
select u.user_id, u.username, sum(ugp.hours_played) as total_hours
from users u
join user_game_progress ugp on u.user_id = ugp.user_id
join games g on ugp.game_id = g.game_id
join game_genres gg on g.game_id = gg.game_id
join genres gen on gg.genre_id = gen.genre_id
where gen.name ilike genre_name
group by u.user_id, u.username
order by total_hours desc
limit 10;
$$ language sql;

create or replace function get_user_activity(start_date date, end_date date) returns table(
    user_id int,
    username varchar,
    activity_date date,
    hours_played int,
    reviews_written int
) as $$
select u.user_id, u.username, d.activity_date,
       coalesce(sum(ugp.hours_played), 0) as hours_played,
       coalesce(count(r.review_id), 0) as reviews_written
from users u
cross join generate_series(start_date, end_date, interval '1 day') as d(activity_date)
left join user_game_progress ugp on u.user_id = ugp.user_id and date(ugp.last_updated) = d.activity_date
left join reviews r on u.user_id = r.user_id and date(r.created_at) = d.activity_date
group by u.user_id, u.username, d.activity_date
order by u.user_id, d.activity_date;
$$ language sql;



create or replace view game_ratings_view as
select g.game_id, g.title, g.release_date,
       coalesce(avg(r.rating), 0) as average_rating,
       count(r.review_id) as review_count
from games g
left join reviews r on g.game_id = r.game_id and r.is_approved = true
group by g.game_id;

create or replace view user_stats_view as
select u.user_id, u.username, u.registration_date,
       count(ugp.progress_id) as total_games,
       count(case when ugp.status = 'Completed' then 1 end) as completed_games,
       coalesce(sum(ugp.hours_played), 0) as total_hours
from users u
left join user_game_progress ugp on u.user_id = ugp.user_id
group by u.user_id;

create or replace view popular_games_view as
select g.game_id, g.title,
       count(ugp.progress_id) as players_count,
       coalesce(avg(r.rating), 0) as average_rating
from games g
left join user_game_progress ugp on g.game_id = ugp.game_id
left join reviews r on g.game_id = r.game_id and r.is_approved = true
group by g.game_id
order by players_count desc
limit 10;



create index if not exists idx_games_company on games(company_id);

create index if not exists idx_reviews_game_approved_rating on reviews (game_id, is_approved) include (rating);

create index if not exists idx_user_progress_user_hours on user_game_progress (user_id) include (hours_played);

create index if not exists idx_user_progress_game on user_game_progress(game_id);

create index if not exists idx_reviews_user on reviews(user_id);

create index if not exists idx_games_release_date on games(release_date);
create index if not exists idx_genres_name on genres(name);
create index if not exists idx_games_title on games(title);

create index if not exists idx_reviews_created_at on reviews(created_at);
create index if not exists idx_user_progress_last_updated on user_game_progress(last_updated);
create index if not exists idx_game_genres_genre_game on game_genres(genre_id, game_id);

create index if not exists idx_reviews_game_created on reviews(game_id, created_at desc);



explain analyze
select get_game_rating(123);

explain analyze
select get_user_total_hours(456);

explain analyze
select * from get_top_players_by_genre('action');

explain analyze
select * from get_user_activity('2024-01-01', '2024-12-31');

explain analyze
select * from game_ratings_view where average_rating > 8.0;

explain analyze
select * from user_stats_view where total_hours > 100;

explain analyze
select * from popular_games_view;

explain analyze
select
    g.title,
    c.name as company,
    count(r.review_id) as review_count,
    avg(r.rating) as avg_rating
from games g
join companies c on g.company_id = c.company_id
left join reviews r on g.game_id = r.game_id and r.is_approved = true
where g.release_date > '2020-01-01'
  and g.title ilike '%game%'
group by g.game_id, g.title, c.name
having count(r.review_id) >= 2
order by avg_rating desc
limit 10;

explain (analyze, buffers, timing)
select u.username, sum(ugp.hours_played) as total_hours
from users u
join user_game_progress ugp on u.user_id = ugp.user_id
join games g on ugp.game_id = g.game_id
join game_genres gg on g.game_id = gg.game_id
join genres gen on gg.genre_id = gen.genre_id
where gen.name = 'RPG'
  and ugp.status = 'Completed'
  and g.release_date > '2010-01-01'
group by u.user_id, u.username
having sum(ugp.hours_played) > 50
order by total_hours desc
limit 10;