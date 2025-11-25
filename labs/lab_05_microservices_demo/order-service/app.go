// File Location: labs/lab_05_microservices_demo/order-service/app.go

package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
)

func healthCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":  "healthy",
		"service": "order-service",
		"version": "1.0.0",
	})
}

func getOrders(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"orders": []map[string]interface{}{},
		"total":  0,
	})
}

func createOrder(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message": "Order created successfully",
		"order":   map[string]interface{}{},
	})
}

func main() {
	http.HandleFunc("/health", healthCheck)
	http.HandleFunc("/api/orders", func(w http.ResponseWriter, r *http.Request) {
		if r.Method == "GET" {
			getOrders(w, r)
		} else if r.Method == "POST" {
			createOrder(w, r)
		}
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	fmt.Printf("Order service starting on port %s\n", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}