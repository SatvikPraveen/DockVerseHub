// File Location: labs/lab_05_microservices_demo/order-service/database/postgres.go

package database

import (
	"database/sql"
	"fmt"
	"os"
	"time"

	_ "github.com/lib/pq"
)

type PostgresDB struct {
	db *sql.DB
}

type Order struct {
	ID        int       `json:"id"`
	UserID    int       `json:"user_id"`
	ProductID int       `json:"product_id"`
	Quantity  int       `json:"quantity"`
	Price     float64   `json:"price"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func NewPostgresDB() (*PostgresDB, error) {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgresql://order:password@localhost:5432/orders?sslmode=disable"
	}

	db, err := sql.Open("postgres", dbURL)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to database: %v", err)
	}

	if err = db.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping database: %v", err)
	}

	return &PostgresDB{db: db}, nil
}

func (p *PostgresDB) CreateOrder(order Order) (*Order, error) {
	query := `
		INSERT INTO orders (user_id, product_id, quantity, price, status)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, created_at, updated_at
	`

	err := p.db.QueryRow(query, order.UserID, order.ProductID, order.Quantity, order.Price, "pending").
		Scan(&order.ID, &order.CreatedAt, &order.UpdatedAt)
	
	if err != nil {
		return nil, err
	}

	order.Status = "pending"
	return &order, nil
}

func (p *PostgresDB) GetOrders(userID int) ([]Order, error) {
	var query string
	var args []interface{}
	
	if userID > 0 {
		query = "SELECT id, user_id, product_id, quantity, price, status, created_at, updated_at FROM orders WHERE user_id = $1 ORDER BY created_at DESC"
		args = append(args, userID)
	} else {
		query = "SELECT id, user_id, product_id, quantity, price, status, created_at, updated_at FROM orders ORDER BY created_at DESC"
	}

	rows, err := p.db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var orders []Order
	for rows.Next() {
		var order Order
		err := rows.Scan(&order.ID, &order.UserID, &order.ProductID, &order.Quantity, 
			&order.Price, &order.Status, &order.CreatedAt, &order.UpdatedAt)
		if err != nil {
			continue
		}
		orders = append(orders, order)
	}

	return orders, nil
}

func (p *PostgresDB) GetOrderByID(id int) (*Order, error) {
	var order Order
	query := "SELECT id, user_id, product_id, quantity, price, status, created_at, updated_at FROM orders WHERE id = $1"
	
	err := p.db.QueryRow(query, id).Scan(&order.ID, &order.UserID, &order.ProductID, 
		&order.Quantity, &order.Price, &order.Status, &order.CreatedAt, &order.UpdatedAt)
	
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("order not found")
	} else if err != nil {
		return nil, err
	}

	return &order, nil
}

func (p *PostgresDB) UpdateOrderStatus(id int, status string) error {
	query := "UPDATE orders SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2"
	result, err := p.db.Exec(query, status, id)
	if err != nil {
		return err
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("order not found")
	}

	return nil
}

func (p *PostgresDB) Close() error {
	return p.db.Close()
}