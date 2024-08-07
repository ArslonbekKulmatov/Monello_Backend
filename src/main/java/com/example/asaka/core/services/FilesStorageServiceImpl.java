package com.example.asaka.core.services;

import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.net.MalformedURLException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Optional;

@Service
public class FilesStorageServiceImpl implements FilesStorageService {
    //Cr By: Arslonbek Kulmatov
    //Saving files into server directory
    @Override
    public void save(MultipartFile file, String file_name, Path root) {
        try {
            Files.copy(file.getInputStream(), root.resolve(file_name));
        } catch (Exception e) {
            throw new RuntimeException("Could not store the file. Reason: " + e.getMessage());
        }
    }

    @Override
    public void init(Path root) {
        try {
            Files.createDirectory(root);
        } catch (IOException e) {
            throw new RuntimeException("Could not initialize folder for upload!");
        }
    }

    //Cr By: Arslonbek Kulmatov
    //Loading files
    @Override
    public Resource load(String filename, Path root) {
        try {
            Path file = root.resolve(filename);
            Resource resource = new UrlResource(file.toUri());

            if (resource.exists() || resource.isReadable()) {
                return resource;
            } else {
                throw new RuntimeException("Could not read the file!");
            }
        } catch (MalformedURLException e) {
            throw new RuntimeException("Error: " + e.getMessage());
        }
    }

    //Cr By: Arslonbek Kulmatov
    //Deleting file from server folder
    @Override
    public void delete(String url) {
        Path path = Paths.get(url);
        try {
            Files.deleteIfExists(path);
        } catch (Exception e) {
            System.out.println("error in deleting file path=" + path + ": Reason: " + e.getMessage());
        }
    }

    //Cr By: Arslonbek Kulmatov
    //Getting file extension type
    @Override
    public Optional<String> getExtensionByStringHandling(String filename) {
        return Optional.ofNullable(filename)
                .filter(f -> f.contains("."))
                .map(f -> f.substring(filename.lastIndexOf(".") + 1));
    }
}

