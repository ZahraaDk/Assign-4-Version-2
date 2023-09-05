-- Identify customers who have never rented films but have made payments.
SELECT
	se_payment.customer_id
FROM payment AS se_payment
INNER JOIN rental AS se_rental
	ON se_rental.rental_id = se_payment.rental_id
WHERE se_rental.rental_id IS null


-- Determine the average number of films rented per customer, broken down by city.
WITH CTE_RENTALS_PER_CUSTOMER_CITY AS ( 
	SELECT 
		COUNT(rental_id) AS total_rentals,
		city
	FROM public.rental AS se_rental
	INNER JOIN public.customer AS se_customer
		ON se_rental.customer_id = se_customer.customer_id
	INNER JOIN public.address AS se_address
		ON se_address.address_id = se_customer.address_id
    INNER JOIN public.city AS se_city   
        ON se_city.city_id = se_address.city_id 
	GROUP BY
		se_address.city_id, 
		se_customer.customer_id
)
SELECT 
	CTE_RENTALS_PER_CUSTOMER_CITY.city,
	ROUND(AVG(total_rentals), 2) AS avg_rentals_per_customer
FROM CTE_RENTALS_PER_CUSTOMER_CITY
GROUP BY 
	CTE_RENTALS_PER_CUSTOMER_CITY.city
    

-- Identify films that have been rented more than the average number of times and are currently not in inventory.
WITH CTE_RENTALS_FILM AS(
	SELECT
		se_film.film_id,
		COUNT(se_rental.rental_id) AS total_rentals
	FROM public.film AS se_film
	LEFT JOIN public.inventory AS se_inventory
		ON se_inventory.film_id = se_film.film_id
	LEFT JOIN public.rental AS se_rental
		ON se_rental.inventory_id = se_inventory.inventory_id
	GROUP BY 
        se_film.film_id
),
CTE_AVG_RENTALS AS (
	SELECT
		AVG(CTE_RENTALS_FILM.total_rentals) AS avg_total_rentals
	FROM CTE_RENTALS_FILM
)
SELECT 
	CTE_RENTALS_FILM.film_id, 
	CTE_AVG_RENTALS.avg_total_rentals
FROM CTE_RENTALS_FILM
INNER JOIN CTE_AVG_RENTALS
	ON CTE_RENTALS_FILM.total_rentals > CTE_AVG_RENTALS.avg_total_rentals
WHERE CTE_RENTALS_FILM.film_id NOT IN(
	SELECT 
		film_id
	FROM public.inventory)


-- Calculate the replacement cost of lost films for each store, considering the rental history.
SELECT
	se_store.store_id, 
	SUM(se_film.replacement_cost) AS total_replacement_cost
FROM public.film AS se_film
INNER JOIN public.inventory AS se_inventory
	ON se_inventory.film_id = se_film.film_id
INNER JOIN public.rental AS se_rental
	on se_rental.inventory_id = se_inventory.inventory_id
INNER JOIN public.staff AS se_staff
	ON se_staff.staff_id = se_rental.staff_id
INNER JOIN public.store AS se_store
	ON se_store.store_id = se_staff.store_id
WHERE se_rental.return_date IS NULL
GROUP BY 
    se_store.store_id


-- Create a report that shows the top 5 most rented films in each category, along with their corresponding rental counts and revenue.
WITH CTE_MOST_RENTED_FILM_IN_CATEGORY AS(
	SELECT 
		se_film.film_id, 
		se_film.title AS film_title, 
		se_category.category_id, 
		se_category.name AS category_name,
		COUNT(se_rental.rental_id) AS rental_count, 
		SUM(se_payment.amount) AS revenue,
		ROW_NUMBER() OVER (PARTITION BY se_category.category_id ORDER BY COUNT(se_rental.rental_id) DESC) AS category_rank
	FROM public.film AS se_film 
	INNER JOIN public.film_category AS se_film_category
		ON se_film_category.film_id = se_film.film_id
	INNER JOIN public.category AS se_category
		ON se_category.category_id = se_film_category.category_id
	LEFT JOIN public.inventory AS se_inventory
		ON se_inventory.film_id = se_film.film_id
	LEFT JOIN public.rental AS se_rental
		ON se_rental.inventory_id = se_inventory.inventory_id
	LEFT JOIN public.payment AS se_payment
		ON se_payment.rental_id = se_rental.rental_id
	GROUP BY 
        se_film.film_id,
        se_category.category_id
)
SELECT 
	CTE_MOST_RENTED_FILM_IN_CATEGORY.category_id, 
	CTE_MOST_RENTED_FILM_IN_CATEGORY.category_name,
	CTE_MOST_RENTED_FILM_IN_CATEGORY.film_title, 
	CTE_MOST_RENTED_FILM_IN_CATEGORY.rental_count, 
	CTE_MOST_RENTED_FILM_IN_CATEGORY.revenue
FROM CTE_MOST_RENTED_FILM_IN_CATEGORY
WHERE CTE_MOST_RENTED_FILM_IN_CATEGORY.category_rank <=5
ORDER BY category_id, rental_count DESC


-- Develop a query that automatically updates the top 10 most frequently rented films.
SELECT 
	se_film.film_id, 
	se_film.title, 
	COUNT(se_rental.rental_id) AS total_rentals
FROM public.film AS se_film
INNER JOIN public.inventory AS se_inventory
	ON se_inventory.film_id = se_film.film_id
INNER JOIN public.rental AS se_rental
	ON se_rental.inventory_id = se_inventory.inventory_id
GROUP BY 
    se_film.film_id
ORDER BY total_rentals DESC
LIMIT 10


-- Identify stores where the revenue from film rentals exceeds the revenue from payments for all customers.
WITH CTE_REVENUE_FROM_RENTALS AS (
	SELECT 
		se_store.store_id,
    	SUM(se_payment.amount) AS rental_revenue
	FROM public.store as se_store
	INNER JOIN public.staff AS se_staff
		ON se_staff.store_id = se_store.store_id
	INNER JOIN public.rental AS se_rental
		ON se_rental.staff_id = se_staff.staff_id
	INNER JOIN public.payment AS se_payment
		ON se_payment.rental_id = se_rental.rental_id
	WHERE se_payment.rental_id IS NOT NULL
	GROUP BY se_store.store_id
),

CTE_REVENUE_FROM_PAYMENT AS (
	SELECT 
		se_store.store_id,
		SUM(amount) AS payment_revenue
	FROM public.payment AS se_payment
	INNER JOIN public.staff AS se_staff
		ON se_staff.staff_id = se_payment.staff_id
	INNER JOIN public.store AS se_store
		ON se_store.store_id = se_staff.store_id
	WHERE rental_id IS NOT NULL
	GROUP BY 
		se_store.store_id
)

SELECT 
  se_store.store_id, 
  rental_revenue, 
  payment_revenue
FROM public.store AS se_store
INNER JOIN CTE_REVENUE_FROM_RENTALS
	ON CTE_REVENUE_FROM_RENTALS.store_id = se_store.store_id
INNER JOIN CTE_REVENUE_FROM_PAYMENT 
	ON CTE_REVENUE_FROM_PAYMENT.store_id = CTE_REVENUE_FROM_RENTALS.store_id
WHERE CTE_REVENUE_FROM_RENTALS.rental_revenue > CTE_REVENUE_FROM_PAYMENT.payment_revenue



-- Determine the average rental duration and total revenue for each store.
SELECT 
	se_inventory.store_id, 
	ROUND(AVG(se_film.rental_duration), 2) AS average_rental_duration, 
	SUM(se_payment.amount) AS total_revenue
FROM payment AS se_payment
INNER JOIN rental AS se_rental
	ON se_rental.rental_id = se_payment.rental_id
INNER JOIN inventory AS se_inventory
	ON se_inventory.inventory_id = se_rental.inventory_id
INNER JOIN film AS se_film
	ON se_film.film_id = se_inventory.film_id
GROUP BY 
	se_inventory.store_id;


-- Analyze the seasonal variation in rental activity and payments for each store.

WITH CTE_VARIATIONS_PER_MONTH AS (
	SELECT 
		se_store.store_id, 
		TO_CHAR(se_rental.rental_date, 'YYYY-MM') AS rental_month,
		COUNT(se_rental.rental_id) AS rental_activity, 
		SUM(se_payment.amount) AS total_revenue
	FROM public.store AS se_store
	INNER JOIN public.staff AS se_staff
		ON se_staff.store_id = se_store.store_id
	INNER JOIN public.rental AS se_rental
		ON se_rental.staff_id = se_staff.staff_id 
	INNER JOIN public.payment AS se_payment 
		ON se_payment.rental_id = se_rental.rental_id
	GROUP BY
		se_store.store_id, 
		rental_month
)
SELECT 
	CTE_VARIATIONS_PER_MONTH.store_id, 
	CTE_VARIATIONS_PER_MONTH.rental_month, 
	ROUND(AVG(CTE_VARIATIONS_PER_MONTH.rental_activity), 2) AS avg_rental_act, 
	ROUND(AVG(CTE_VARIATIONS_PER_MONTH.total_revenue), 2) AS avg_revenue
FROM CTE_VARIATIONS_PER_MONTH
GROUP BY 
	store_id, 
	rental_month
ORDER BY store_id, rental_month
