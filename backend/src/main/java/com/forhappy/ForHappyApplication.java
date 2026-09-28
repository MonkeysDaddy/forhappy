package com.forhappy;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
@MapperScan("com.forhappy.**.mapper")
public class ForHappyApplication {

    public static void main(String[] args) {
        SpringApplication.run(ForHappyApplication.class, args);
    }
}
