%dw 2.0
import * from dw::test::Asserts
---
payload must anyOf([
	equalTo({
	  "message": "Mule CI/CD Test Successfull",
	  "environment": "development"
	}),
		equalTo({
	  "message": "Mule CI/CD Test Successfull",
	  "environment": "test"
	}),
	equalTo({
	  "message": "Mule CI/CD Test Successfull",
	  "environment": "production"
	})

])
