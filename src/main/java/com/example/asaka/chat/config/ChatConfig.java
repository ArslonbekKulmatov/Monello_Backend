package com.example.asaka.chat.config;

import com.anthropic.client.AnthropicClient;
import com.anthropic.client.okhttp.AnthropicOkHttpClient;
import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Chat (Text-to-SQL) uchun alohida resurslar.
 *
 * Read-only DataSource asosiy `hds` dan butunlay ajratilgan: Claude yozgan SQL
 * faqat shu pool orqali bajariladi va MONELLO_CHAT_RO user'ida DML/DDL grant yo'q.
 *
 * Proksi: Anthropic API ga chiqish uchun JVM'ga standart `https.proxyHost` /
 * `https.proxyPort` system property'larini bering (OkHttp ularni avtomatik oladi).
 */
@Configuration
@ConditionalOnProperty(name = "chat.enabled", havingValue = "true")
public class ChatConfig {

  @Value("${chat.datasource.url}")      String url;
  @Value("${chat.datasource.username}") String username;
  @Value("${chat.datasource.password}") String password;
  @Value("${chat.datasource.pool-size:5}") int poolSize;

  @Value("${anthropic.api-key:}") String apiKey;

  @Bean(name = "chatReadOnlyDataSource", destroyMethod = "close")
  public HikariDataSource chatReadOnlyDataSource() {
    HikariConfig cfg = new HikariConfig();
    cfg.setJdbcUrl(url);
    cfg.setUsername(username);
    cfg.setPassword(password);
    cfg.setDriverClassName("oracle.jdbc.driver.OracleDriver");
    cfg.setPoolName("MonelloChatReadOnlyCP");
    cfg.setMaximumPoolSize(poolSize);
    cfg.setMinimumIdle(1);
    cfg.setIdleTimeout(60_000);
    cfg.setMaxLifetime(120_000);
    cfg.setConnectionTimeout(15_000);
    cfg.setReadOnly(true);
    return new HikariDataSource(cfg);
  }

  @Bean
  public AnthropicClient anthropicClient() {
    if (apiKey == null || apiKey.isBlank()) {
      // ANTHROPIC_API_KEY muhit o'zgaruvchisidan olinadi
      return AnthropicOkHttpClient.fromEnv();
    }
    return AnthropicOkHttpClient.builder().apiKey(apiKey).build();
  }
}
