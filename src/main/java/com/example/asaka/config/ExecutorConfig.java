package com.example.asaka.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

import java.util.concurrent.*;

@Slf4j
@Configuration
@EnableAsync
public class ExecutorConfig {
    @Value("${executor.corePoolSize}")
    private int corePoolSize;

    @Value("${executor.maxPoolSize}")
    private int maxPoolSize;

    @Value("${executor.queueCapacity}")
    private int queueCapacity;

    @Value("${executor.setAliveSeconds}")
    private int setAliveSeconds;

    @Value("${executor.threadName}")
    private String threadName;

    @Bean(name = "requestExecutor")
    public ThreadPoolTaskExecutor taskExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor(){
            @Override
            protected BlockingQueue<Runnable> createQueue(int queueCapacity) {
                // Use SynchronousQueue instead of the default LinkedBlockingQueue
                return new SynchronousQueue<>();
            }

            @Override
            public void execute(Runnable task) {
                super.execute(wrapTask(task, setAliveSeconds));
            }
        };
        // Set the core pool size to handle the initial load
        executor.setCorePoolSize(corePoolSize);
        // Set the maximum pool size to handle peak load
        executor.setMaxPoolSize(maxPoolSize);
        // Set the queue capacity to buffer the incoming requests
        executor.setQueueCapacity(queueCapacity);
        // Set a custom thread name prefix for easier identification
        executor.setThreadNamePrefix(threadName);
        // Set the keep-alive time for excess idle threads (optional)
        executor.setKeepAliveSeconds(setAliveSeconds);
        // Allow core threads to time out
        executor.setAllowCoreThreadTimeOut(true);
        // Set the rejection policy for handling overflow
        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.AbortPolicy());
        executor.initialize();
        return executor;
    }

    /**
     * Wraps a task to enforce a timeout.
     */
    //Cr By: Arslonbek Kulmatov
    //To clean up threads long running
    private Runnable wrapTask(Runnable task, int timeoutSeconds) {
        return () -> {
            Future<?> future = null;
            try {
                ExecutorService timeoutExecutor = Executors.newSingleThreadExecutor();
                future = timeoutExecutor.submit(task);
                future.get(timeoutSeconds, TimeUnit.SECONDS);  // Enforce the timeout
            } catch (TimeoutException e) {
                // Task exceeded the time limit, cancel it
                future.cancel(true);
                // Log or handle timeout
                log.info("Task exceeded the time limit and was canceled.");
            } catch (InterruptedException | ExecutionException e) {
                // Handle other possible exceptions
                log.info("Task execution encountered an exception: " + e.getMessage());
            }
        };
    }
}
