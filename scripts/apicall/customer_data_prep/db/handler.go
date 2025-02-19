package db

import (
	"fmt"
	"log"
	"time"

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
	dbObj, err := gorm.Open(sqlserver.Open(dsn), &gormConfig)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
		return nil, err
	}
	fmt.Println("Connected to MSSQL successfully!")

	db, err := dbObj.DB()
	if err != nil {
		log.Fatalf("Failed to get DB object: %v", err)
		return nil, err
	}

	db.SetConnMaxIdleTime(30*time.Second)
	db.SetConnMaxLifetime(10 * time.Minute)
	db.SetMaxIdleConns(200)
	db.SetMaxOpenConns(200)

	return dbObj, nil
}
