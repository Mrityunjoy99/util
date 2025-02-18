package db

import (
	"fmt"
	"log"

	"gorm.io/driver/sqlserver"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func GetDefaultDB() (*gorm.DB, error) {
	server := "cbs-db-1.c3wosu4uq6vu.ap-south-2.rds.amazonaws.com"
	port := 1433
	user := "admin"
	password := "lYO4113fIMg3IkL5"
	database := "BSGACCOUNTING"

	// Connection string
	dsn := fmt.Sprintf("sqlserver://%s:%s@%s:%d?database=%s&encrypt=disable",
		user, password, server, port, database)

	gormConfig := gorm.Config{
		SkipDefaultTransaction: true,
		Logger:                 logger.Default.LogMode(logger.Info),
	}

	// Connect to the database using GORM
	db, err := gorm.Open(sqlserver.Open(dsn), &gormConfig)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
		return nil, err
	}
	fmt.Println("Connected to MSSQL successfully!")

	return db, nil
}
