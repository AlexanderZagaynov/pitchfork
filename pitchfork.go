package main

import (
	"log"
	"fmt"
	// "flag"
	"io/ioutil"
	"gopkg.in/yaml.v2"
)

type Host struct {
	Name string
	Root string
	User string
	Auth string
}

type Remote struct {
	Host *Host
	Owner string
	Parent *Host
}

type Config struct {
	Hosts map[string]Host
	Remotes map[string]Remote
}

func readConfig(fileName string) { //, config *Config) {
	var config Config

	fileData, err := ioutil.ReadFile(fileName)
	if err != nil {
		log.Printf("Read config: #%v ", err)
	}

	err = yaml.Unmarshal(fileData, &config)
	if err != nil {
		log.Fatalf("%+v\n", err)
	}

	fmt.Printf("%+v\n", config)
}

func main() {
	// var config Config

	readConfig(".pitchfork.yml") //, &config)
	// readConfig(".pitchfork.local.yml") //, &config)
}
