package com.forhappy;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@MapperScan("com.forhappy.**.mapper")
@EnableScheduling
public class ForHappyApplication {

    public static void main(String[] args) {
        SpringApplication.run(ForHappyApplication.class, args);
    }
}
