package com.example.asaka.config;

import org.springframework.context.annotation.Configuration;
//import java.util.Collections;

@Configuration
public class SpringFoxConfig {


//    .apis(RequestHandlerSelectors.basePackage("guru.springframework.controllers"))
//            .paths(regex("/product.*"))

//
//	@Bean
//	public Docket fidoapi(){
//		return new Docket(DocumentationType.SWAGGER_2)
//			.globalOperationParameters(getGlobalParameters())
//			.select()
//			.apis(RequestHandlerSelectors.basePackage("com.edu.main"))
//			.paths(PathSelectors.any())
//			.build()
//			.apiInfo(metaData());
//	}
//
//	private ApiInfo metaData(){
//		return new ApiInfoBuilder()
//			.title("Learn Without Rest")
//			.description("Learning App")
//			.version("1.0.0")
//			.license("Apache License version 2.0")
//			.contact(new Contact("Uzoqov Abror","","auzoqov.born@gmail.com"))
//			.build();
//	}
//
//	private List<Parameter> getGlobalParameters(){
//		Parameter tokenParameter = new ParameterBuilder()
//			.name("token")
//			.description("Token")
//			.modelRef(new ModelRef("string"))
//			.parameterType("header")
//			.required(false)
//			.build();
//
//		Parameter serialParameter = new ParameterBuilder()
//			.name("device-id")
//			.description("Serial number of device")
//			.modelRef(new ModelRef("string"))
//			.parameterType("header")
//			.required(false)
//			.build();
//
//		Parameter langParameter = new ParameterBuilder()
//			.name("lang")
//			.description("Required language")
//			.modelRef(new ModelRef("string"))
//			.parameterType("header")
//			.defaultValue("EN")
//			.required(false)
//			.build();
//
//		Parameter appVersionParameter = new ParameterBuilder()
//			.name("app-version")
//			.description("App Version")
//			.modelRef(new ModelRef("string"))
//			.parameterType("header")
//			.defaultValue("IV2.0.1")
//			.required(true)
//			.build();
//
//		return Arrays.asList(tokenParameter, serialParameter, langParameter, appVersionParameter);
//	}

}
