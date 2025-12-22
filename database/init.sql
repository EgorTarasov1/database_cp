create table users (
    user_id serial primary key,
    username varchar(50) not null unique,
    email varchar(100) not null unique check (email ~* '^[a-za-z0-9._+%-]+@[a-za-z0-9.-]+[.][a-za-z]+$'),
    password_hash varchar(255) not null,
    registration_date date not null default current_date,
    is_active boolean not null default true,
    bio text
);

create table companies (
    company_id serial primary key,
    name varchar(100) not null unique,
    founded_year int check (founded_year > 1900 and founded_year <= extract(year from current_date)),
    country varchar(50),
    website varchar(255),
    role varchar(20) not null check (role in ('Developer', 'Publisher', 'Both')),
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
    release_date date,
    developer_id int,
    publisher_id int,
    created_at timestamp not null default current_timestamp
);

alter table games add foreign key (developer_id) references companies(company_id) on delete set null on update cascade;
alter table games add foreign key (publisher_id) references companies(company_id) on delete set null on update cascade;

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
    created_at timestamp not null default current_timestamp,
    foreign key (user_id) references users(user_id) on delete cascade
);

create table user_profiles (
    user_id int primary key,
    avatar_url varchar(255),
    birth_date date check (birth_date <= current_date),
    country varchar(50),
    website varchar(255),
    created_at timestamp not null default current_timestamp,
    foreign key (user_id) references users(user_id) on delete cascade
);

create table audit_log (
    log_id serial primary key,
    table_name varchar(50) not null,
    operation char(7) not null check (operation in ('INSERT', 'UPDATE', 'DELETE')),
    row_id int not null,
    changed_by int,
    old_values jsonb,
    new_values jsonb,
    changed_at timestamp not null default current_timestamp,
    foreign key (changed_by) references users(user_id) on delete set null on update cascade
);





create or replace view game_ratings_view as
select
    g.game_id,
    g.title,
    g.release_date,
    round(avg(r.rating)::numeric, 2) as average_rating,
    count(r.review_id) as review_count
from games g
left join reviews r on g.game_id = r.game_id
where r.is_approved = true
group by g.game_id, g.title, g.release_date
order by average_rating desc;


create or replace view user_stats_view as
select
    u.user_id,
    u.username,
    u.registration_date,
    count(ugp.game_id) as total_games,
    sum(case when ugp.status = 'completed' then 1 else 0 end) as completed_games,
    coalesce(sum(ugp.hours_played), 0) as total_hours
from users u
left join user_game_progress ugp on u.user_id = ugp.user_id
group by u.user_id, u.username, u.registration_date
order by total_hours desc;


create or replace view popular_games_view as
select
    g.game_id,
    g.title,
    count(distinct ugp.user_id) as players_count,
    round(avg(r.rating)::numeric, 2) as average_rating
from games g
left join user_game_progress ugp on g.game_id = ugp.game_id
left join reviews r on g.game_id = r.game_id and r.is_approved = true
group by g.game_id, g.title
having count(r.review_id) >= 2
order by players_count desc, average_rating desc
limit 20;






create or replace function current_app_user_id()
returns int as $$
begin
    return current_setting('app.current_user_id', true)::int;
exception
    when others then
        return null;
end;
$$ language plpgsql;



create or replace function audit_reviews_function()
returns trigger as $$
begin
	insert into audit_log (
	    table_name,
	    operation,
	    row_id,
	    changed_by,
	    old_values,
	    new_values
	)
	values (
	    'reviews',
	    tg_op,
	    coalesce(new.review_id, old.review_id),
	    current_app_user_id(),
	    row_to_json(old),
	    row_to_json(new)
	);
    return null;
end;
$$ language plpgsql;

create trigger audit_reviews_trigger
after insert or update or delete on reviews
for each row execute function audit_reviews_function();


create or replace function audit_users_function()
returns trigger as $$
begin
	insert into audit_log (
	    table_name,
	    operation,
	    row_id,
	    changed_by,
	    old_values,
	    new_values
	)
	values (
	    'users',
	    tg_op,
	    coalesce(new.user_id, old.user_id),
	    current_app_user_id(),
	    row_to_json(old),
	    row_to_json(new)
	);
    return null;
end;
$$ language plpgsql;

create trigger audit_users_trigger
after insert or update on users
for each row execute function audit_users_function();


create or replace function update_last_played_function()
returns trigger as $$
begin
    new.last_played = current_timestamp;
    return new;
end;
$$ language plpgsql;

create trigger update_last_played_trigger
before update on user_game_progress
for each row execute function update_last_played_function();



create or replace function audit_user_game_progress_function()
returns trigger as $$
begin
    insert into audit_log (
        table_name,
        operation,
        row_id,
        changed_by,
        old_values,
        new_values
    )
    values (
        'user_game_progress',
        tg_op,
        coalesce(new.progress_id, old.progress_id),
        current_app_user_id(),
        row_to_json(old),
        row_to_json(new)
    );
    return null;
end;
$$ language plpgsql;

create trigger audit_user_game_progress_trigger
after insert or update or delete on user_game_progress
for each row execute function audit_user_game_progress_function();


create table game_aggregates (
    game_id int primary key references games(game_id) on delete cascade,
    reviews_count int not null default 0,
    avg_rating numeric(4,2) not null default 0
);

create or replace function update_game_aggregates()
returns trigger as $$
begin
    update game_aggregates
    set
        reviews_count = (
            select count(*) from reviews
            where game_id = new.game_id and is_approved = true
        ),
        avg_rating = (
            select round(avg(rating)::numeric, 2) from reviews
            where game_id = new.game_id and is_approved = true
        )
    where game_id = new.game_id;

    return null;
end;
$$ language plpgsql;

create trigger update_game_aggregates_trigger
after insert or update or delete on reviews
for each row execute function update_game_aggregates();




create or replace function get_game_rating(game_id_param int)
returns decimal(5,2) as $$
declare
    avg_rating decimal(3,2);
begin
    select round(avg(rating)::numeric, 2) into avg_rating
    from reviews
    where game_id = game_id_param and is_approved = true;

    return coalesce(avg_rating, 0.00);
end;
$$ language plpgsql;


create or replace function get_user_total_hours(user_id_param int)
returns int as $$
declare
    total_hours int;
begin
    select sum(hours_played) into total_hours
    from user_game_progress
    where user_id = user_id_param;

    return coalesce(total_hours, 0);
end;
$$ language plpgsql;


create or replace function get_top_players_by_genre(genre_name_param varchar)
returns table (
    username varchar,
    total_hours int,
    completed_games int
) as $$
begin
    return query
    select
        u.username,
        sum(ugp.hours_played)::int as total_hours,
        sum(case when ugp.status = 'completed' then 1 else 0 end)::int as completed_games
    from users u
    join user_game_progress ugp on u.user_id = ugp.user_id
    join games g on ugp.game_id = g.game_id
    join game_genres gg on g.game_id = gg.game_id
    join genres gen on gg.genre_id = gen.genre_id
    where gen.name ilike '%' || genre_name_param || '%'
    group by u.user_id, u.username
    order by total_hours desc
    limit 10;
end;
$$ language plpgsql;


create or replace function get_user_activity(start_date_param date, end_date_param date)
returns table (
    username varchar,
    reviews_count int,
    games_added int
) as $$
begin
    return query
    select
        u.username,
        count(r.review_id)::int as reviews_count,
        count(ugp.game_id)::int as games_added
    from users u
    left join reviews r on u.user_id = r.user_id
        and r.created_at between start_date_param and end_date_param
    left join user_game_progress ugp on u.user_id = ugp.user_id
        and ugp.last_updated between start_date_param and end_date_param
    group by u.user_id, u.username
    order by reviews_count desc;
end;
$$ language plpgsql;




create index if not exists idx_games_developer on games(developer_id);
create index if not exists idx_games_publisher on games(publisher_id);
create index if not exists idx_user_progress_user on user_game_progress(user_id);
create index if not exists idx_user_progress_game on user_game_progress(game_id);
create index if not exists idx_reviews_game on reviews(game_id);
create index if not exists idx_reviews_user on reviews(user_id);

create index if not exists idx_games_release_date on games(release_date);
create index if not exists idx_genres_name on genres(name);
create index if not exists idx_games_title on games(title);

create index if not exists idx_reviews_game_approved on reviews(game_id) where is_approved = true;
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
    c.name as developer,
    count(r.review_id) as review_count,
    avg(r.rating) as avg_rating
from games g
join companies c on g.developer_id = c.company_id
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
where gen.name = 'rpg'
  and ugp.status = 'completed'
  and g.release_date > '2010-01-01'
group by u.user_id, u.username
having sum(ugp.hours_played) > 50
order by total_hours desc
limit 10;


--drop index if exists idx_games_developer;
--drop index if exists idx_games_publisher;
--drop index if exists idx_user_progress_user;
--drop index if exists idx_user_progress_game;
--drop index if exists idx_reviews_game;
--drop index if exists idx_reviews_user;
--drop index if exists idx_games_release_date;
--drop index if exists idx_genres_name;
--drop index if exists idx_games_title;
--drop index if exists idx_reviews_game_approved;
--drop index if exists idx_reviews_created_at;
--drop index if exists idx_user_progress_last_updated;
--drop index if exists idx_game_genres_genre_game;
--drop index if exists idx_reviews_game_created;























