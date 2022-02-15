 №1 В каких городах больше одного аэропорта? 

select city as "Города"
from (
	select city, count(airport_name) as count
	from airports a
	group by city) t
where count > 1

№2 В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета?

select a2.airport_name as "Аэропорты"
from (
	select aircraft_code, row_number() over (order by "range" desc) as r_w
	from aircrafts a) t 
left join flights f on t.aircraft_code = f.aircraft_code 
left join airports a2 on f.departure_airport = a2.airport_code
where r_w = 1
group by a2.airport_name 

№3 Вывести 10 рейсов с максимальным временем задержки вылета

select flight_no  as "Рейсы" 
from(
	select flight_no, (actual_departure - scheduled_departure)
	from flights 
	where actual_departure is not null and actual_departure > scheduled_departure
	order by 2 desc) t
limit 10

№4 Были ли брони, по которым не были получены посадочные талоны?

select b.book_ref 
from bookings b 
full outer join tickets t on b.book_ref = t.book_ref
left join boarding_passes bp on bp.ticket_no = t.ticket_no 
where bp.ticket_no is null or bp.flight_id is null */

№5 Найдите количество свободных мест для каждого рейса, их % отношение к общему количеству мест в самолете.
Добавьте столбец с накопительным итогом - суммарное накопление количества вывезенных пассажиров из каждого аэропорта на каждый день. 
Т.е. в этом столбце должна отражаться накопительная сумма - сколько человек уже вылетело из данного аэропорта на этом или более ранних рейсах в течении дня.

select res.flight_id, res.actual_departure, res.departure_airport, q.count - res.count  as "Cвободные места", round((1- (res.count::numeric / q.count::numeric))*100 , 2) as "Свободные места, %", res.count as "Вывезено", res.sum as "Накопление"
from (
	select f.flight_id, f.actual_departure, a.aircraft_code , f.departure_airport, count(tf.ticket_no), sum(count(tf.ticket_no)) over (partition by f.actual_departure::date, f.departure_airport order by f.flight_id asc)
	from flights f 
	left join ticket_flights tf on f.flight_id = tf.flight_id 
	join aircrafts a on a.aircraft_code = f.aircraft_code 
	where f.actual_departure is not null
	group by f.flight_id, f.actual_departure, f.arrival_airport, a.aircraft_code) res
left join (
select s.aircraft_code, count(s.seat_no)
from seats s 
group by s.aircraft_code) q on res.aircraft_code = q.aircraft_code 
order by 3,2

№6 Найдите процентное соотношение перелетов по типам самолетов от общего количества. 

select distinct a.model, 
	round((count(f.flight_id) over (partition by f.aircraft_code)::numeric / count(f.flight_id) over ())*100,2) || '%' as "Процентное соотношение"
from flights f
left join aircrafts a on f.aircraft_code = a.aircraft_code
where f.actual_departure is not null 

№7 Были ли города, в которые можно  добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета?

with eco as (
	select f.flight_id, tf.amount 
	from ticket_flights tf 
	left join flights f on tf.flight_id = f.flight_id
	left join airports a on f.arrival_airport = a.airport_code 
	where tf.fare_conditions = ‘Economy’),
bus as (
	select f.flight_id, tf.amount, a.city 
	from ticket_flights tf 
	left join flights f on tf.flight_id = f.flight_id
	left join airports a on f.arrival_airport = a.airport_code 
	where tf.fare_conditions = ‘Business’)
select bus.city
from eco
join bus on eco.flight_id = bus.flight_id 
where eco.amount > bus.amount 
group by bus.city

№8 Между какими городами нет прямых рейсов?

CREATE VIEW cities as
SELECT a.city as dep, a2.city as arr
FROM airports a, airports a2
where a.city != a2.city 

select *
from cities 
except (
with dep as
(
select distinct f.flight_no, a.city 
from flights f 
left join airports a on f.departure_airport = a.airport_code 
), 
arr as 
(
select distinct f.flight_no, a.city 
from flights f 
left join airports a on f.arrival_airport = a.airport_code 
)  
select dep.city, arr.city 
from dep  
left join arr on dep.flight_no = arr.flight_no)
order by 1,2

№9 Вычислите расстояние между аэропортами, связанными прямыми рейсами, сравните с допустимой максимальной дальностью перелетов  в самолетах,
 * обслуживающих эти рейсы *

with coor1 as(
	select f.flight_no, f.departure_airport, f.aircraft_code, radians(a.longitude) as long, radians(a.latitude) as lat
	from airports a  
	full outer join flights f on a.airport_code = f.departure_airport
	where f.actual_departure is not null),
coor2 as (
	select f.flight_no, f.arrival_airport, radians(a.longitude) as long, radians(a.latitude) as lat
	from airports a  
	full outer join flights f on a.airport_code = f.arrival_airport
	where f.actual_arrival is not null)
select count(*),coor1.flight_no as "№", coor1.departure_airport as "Вылет", coor2.arrival_airport as "Прибытие", (6371 * acos(sin(coor1.lat)*sin(coor2.lat) + cos(coor1.lat)*cos(coor2.lat)*cos(coor1.long - coor2.long)))::int as "Расстояние", a2.range as "Максимальное расс-е самолета",
	case 
		when (6371 * (acos(sin(coor1.lat)*sin(coor2.lat) + cos(coor1.lat)*cos(coor2.lat)*cos(coor1.long - coor2.long)))::int) < a2."range"::int then 'Максимальное расс-е самолета больше'
		else 'Максимальное расс-е самолета меньше'
	end as "Перелет"
from coor1
inner join coor2 on coor1.flight_no = coor2.flight_no
left join aircrafts a2 on coor1.aircraft_code = a2.aircraft_code 
group by coor1.flight_no, coor1.departure_airport, coor2.arrival_airport, coor1.lat, coor1.long, coor2.lat, coor2.long, a2.range 