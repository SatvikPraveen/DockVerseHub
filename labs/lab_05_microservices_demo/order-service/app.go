// File Location: labs/lab_05_microservices_demo/order-service/app.go

package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/gorilla/mux"
	"github.com/lib/pq"
	"database/sql"
	"github.com/streadway/amqp"
	_ "github.com/lib/pq"
)

type Order struct {
	ID          int       `json:"id"`
	UserID      int       `json:"user_id"`
	ProductID   int       `json:"product_id"`
	Quantity    int       `json:"quantity"`
	Price       float64   `json:"price"`
	Status      string    `json:"status"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type OrderService struct {
	db   *sql.DB
	amqp *amqp.Connection
}

func NewOrderService() *OrderService {
	return &OrderService{}
}

func (s *OrderService) InitDB() error {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgresql://order:password@localhost:5432/orders?sslmode=disable"
	}

	var err error
	s.db, err = sql.Open("postgres", dbURL)
	if err != nil {
		return fmt.Errorf("failed to connect to database: %v", err)
	}

	if err = s.db.Ping(); err != nil {
		return fmt.Errorf("failed to ping database: %v", err)
	}

	// Create orders table if not exists
	createTableSQL := `
	CREATE TABLE IF NOT EXISTS orders (
		id SERIAL PRIMARY KEY,
		user_id INTEGER NOT NULL,
		product_id INTEGER NOT NULL,
		quantity INTEGER NOT NULL,
		price DECIMAL(10,2) NOT NULL,
		status VARCHAR(20) DEFAULT 'pending',
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	)`

	if _, err = s.db.Exec(createTableSQL); err != nil {
		return fmt.Errorf("failed to create table: %v", err)
	}

	log.Println("Database connected successfully")
	return nil
}

func (s *OrderService) InitMQ() error {
	mqURL := os.Getenv("RABBITMQ_URL")
	if mqURL == "" {
		mqURL = "amqp://guest:guest@localhost:5672/"
	}

	var err error
	s.amqp, err = amqp.Dial(mqURL)
	if err != nil {
		return fmt.Errorf("failed to connect to RabbitMQ: %v", err)
	}

	log.Println("RabbitMQ connected successfully")
	return nil
}

func (s *OrderService) PublishEvent(eventType string, data interface{}) error {
	ch, err := s.amqp.Channel()
	if err != nil {
		return err
	}
	defer ch.Close()

	// Declare exchange
	err = ch.ExchangeDeclare(
		"orders",
		"topic",
		true,
		false,
		false,
		false,
		nil,
	)
	if err != nil {
		return err
	}

	body, err := json.Marshal(map[string]interface{}{
		"event_type": eventType,
		"data":       data,
		"timestamp":  time.Now().UTC(),
	})
	if err != nil {
		return err
	}

	return ch.Publish(
		"orders",
		fmt.Sprintf("order.%s", eventType),
		false,
		false,
		amqp.Publishing{
			ContentType: "application/json",
			Body:        body,
		},
	)
}

func (s *OrderService) HealthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	
	health := map[string]interface{}{
		"status":    "healthy",
		"service":   "order-service",
		"version":   "1.0.0",
		"timestamp": time.Now().UTC(),
	}

	// Check database connection
	if err := s.db.Ping(); err != nil {
		health["status"] = "unhealthy"
		health["database"] = "disconnected"
		w.WriteHeader(http.StatusServiceUnavailable)
	} else {
		health["database"] = "connected"
	}

	// Check RabbitMQ connection
	if s.amqp == nil || s.amqp.IsClosed() {
		health["status"] = "degraded"
		health["rabbitmq"] = "disconnected"
	} else {
		health["rabbitmq"] = "connected"
	}

	json.NewEncoder(w).Encode(health)
}

func (s *OrderService) CreateOrder(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	var order Order
	if err := json.NewDecoder(r.Body).Decode(&order); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	// Validate required fields
	if order.UserID == 0 || order.ProductID == 0 || order.Quantity <= 0 || order.Price <= 0 {
		http.Error(w, "Missing required fields", http.StatusBadRequest)
		return
	}

	// Insert order into database
	query := `
		INSERT INTO orders (user_id, product_id, quantity, price, status)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, created_at, updated_at
	`

	err := s.db.QueryRow(query, order.UserID, order.ProductID, order.Quantity, order.Price, "pending").
		Scan(&order.ID, &order.CreatedAt, &order.UpdatedAt)
	
	if err != nil {
		log.Printf("Error creating order: %v", err)
		http.Error(w, "Failed to create order", http.StatusInternalServerError)
		return
	}

	order.Status = "pending"

	// Publish order created event
	if err := s.PublishEvent("created", order); err != nil {
		log.Printf("Failed to publish event: %v", err)
	}

	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message": "Order created successfully",
		"order":   order,
	})
}

func (s *OrderService) GetOrders(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	userID := r.URL.Query().Get("user_id")
	
	var query string
	var args []interface{}
	
	if userID != "" {
		query = "SELECT id, user_id, product_id, quantity, price, status, created_at, updated_at FROM orders WHERE user_id = $1 ORDER BY created_at DESC"
		args = append(args, userID)
	} else {
		query = "SELECT id, user_id, product_id, quantity, price, status, created_at, updated_at FROM orders ORDER BY created_at DESC"
	}

	rows, err := s.db.Query(query, args...)
	if err != nil {
		log.Printf("Error querying orders: %v", err)
		http.Error(w, "Failed to get orders", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var orders []Order
	for rows.Next() {
		var order Order
		err := rows.Scan(&order.ID, &order.UserID, &order.ProductID, &order.Quantity, 
			&order.Price, &order.Status, &order.CreatedAt, &order.UpdatedAt)
		if err != nil {
			log.Printf("Error scanning order: %v", err)
			continue
		}
		orders = append(orders, order)
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"orders": orders,
		"total":  len(orders),
	})
}

func (s *OrderService) GetOrderByID(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	
	vars := mux.Vars(r)
	orderID, err := strconv.Atoi(vars["id"])
	if err != nil {
		http.Error(w, "Invalid order ID", http.StatusBadRequest)
		return
	}

	var order Order
	query := "SELECT id, user_id, product_id, quantity, price, status, created_at, updated_at FROM orders WHERE id = $1"
	
	err = s.db.QueryRow(query, orderID).Scan(&order.ID, &order.UserID, &order.ProductID, 
		&order.Quantity, &order.Price, &order.Status, &order.CreatedAt, &order.UpdatedAt)
	
	if err == sql.ErrNoRows {
		http.Error(w, "Order not found", http.StatusNotFound)
		return
	} else if err != nil {
		log.Printf("Error getting order: %v", err)
		http.Error(w, "Failed to get order", http.StatusInternalServerError)
		return
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"order": order,
	})
}

func (s *OrderService) UpdateOrderStatus(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	
	vars := mux.Vars(r)
	orderID, err := strconv.Atoi(vars["id"])
	if err != nil {
		http.Error(w, "Invalid order ID", http.StatusBadRequest)
		return
	}

	var req struct {
		Status string `json:"status"`
	}
	
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	// Validate status
	validStatuses := map[string]bool{
		"pending": true, "confirmed": true, "shipped": true, "delivered": true, "cancelled": true,
	}
	
	if !validStatuses[req.Status] {
		http.Error(w, "Invalid status", http.StatusBadRequest)
		return
	}

	query := "UPDATE orders SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2"
	result, err := s.db.Exec(query, req.Status, orderID)
	if err != nil {
		log.Printf("Error updating order: %v", err)
		http.Error(w, "Failed to update order", http.StatusInternalServerError)
		return
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		http.Error(w, "Order not found", http.StatusNotFound)
		return
	}

	// Publish order updated event
	if err := s.PublishEvent("status_updated", map[string]interface{}{
		"order_id": orderID,
		"status":   req.Status,
	}); err != nil {
		log.Printf("Failed to publish event: %v", err)
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"message": "Order status updated successfully",
		"order_id": orderID,
		"status": req.Status,
	})
}

func main() {
	service := NewOrderService()
	
	if err := service.InitDB(); err != nil {
		log.Fatal("Failed to initialize database:", err)
	}
	defer service.db.Close()

	if err := service.InitMQ(); err != nil {
		log.Printf("Warning: Failed to initialize RabbitMQ: %v", err)
	} else {
		defer service.amqp.Close()
	}

	r := mux.NewRouter()
	
	// Routes
	r.HandleFunc("/health", service.HealthCheck).Methods("GET")
	r.HandleFunc("/api/orders", service.CreateOrder).Methods("POST")
	r.HandleFunc("/api/orders", service.GetOrders).Methods("GET")
	r.HandleFunc("/api/orders/{id:[0-9]+}", service.GetOrderByID).Methods("GET")
	r.HandleFunc("/api/orders/{id:[0-9]+}/status", service.UpdateOrderStatus).Methods("PUT")

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Order service starting on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}