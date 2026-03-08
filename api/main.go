package main

import (
	"fmt"
	"net/http"
)

func healthHandler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "OK")
}

func main() {
	http.HandleFunc("/health", healthHandler)

	fmt.Println("Server running on port 8080")
	http.ListenAndServe(":8080", nil)
}
