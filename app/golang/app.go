package main

import (
	"io"
	"fmt"
	"context"
	"net/http"
	"encoding/json"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// funcion principal
func main() {

	http.HandleFunc("/music", getHome)
	http.HandleFunc("/music/post", postBand)
	http.HandleFunc("/music/get", getBand)
	http.ListenAndServe(":9081", nil)
}

// funcion de estado
func getHome(w http.ResponseWriter, r *http.Request) {
    raw := json.RawMessage(`{"api":"music","version":"v0.0.2"}`)
    jsonResp, err := json.Marshal(&raw)
    if err != nil {
        panic(err)
    }
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(jsonResp)
	return
}

// funcion de inserción
func postBand(w http.ResponseWriter, r *http.Request) {
	client, err := mongo.Connect(context.TODO(), options.Client().ApplyURI("mongodb://mongo:27017"))
	if err != nil {
		panic(err)
	}

	fmt.Println("POST params were:", r.URL.Query())
	name := r.URL.Query().Get("name")

	bandsCollection := client.Database("Music").Collection("bands")
	band := bson.D{{"name", name}}
	result, err := bandsCollection.InsertOne(context.TODO(), band)
	if err != nil {
		panic(err)
	}
	fmt.Println(result.InsertedID)
	w.WriteHeader(http.StatusOK)
}

// funcion de consulta
func getBand(w http.ResponseWriter, r *http.Request) {
	client, err := mongo.Connect(context.TODO(), options.Client().ApplyURI("mongodb://mongo:27017"))
	if err != nil {
		panic(err)
	}

	bandsCollection := client.Database("Music").Collection("bands")

	cursor, err := bandsCollection.Find(context.TODO(), bson.D{})
	if err != nil {
		panic(err)
	}

	var results []bson.M
	if err = cursor.All(context.TODO(), &results); err != nil {
		panic(err)
	}

    jsonStr, err := json.Marshal(results)
    if err != nil {
        fmt.Printf("Error: %s", err.Error())
    }
	w.WriteHeader(http.StatusOK)
	io.WriteString(w, string(jsonStr))
}