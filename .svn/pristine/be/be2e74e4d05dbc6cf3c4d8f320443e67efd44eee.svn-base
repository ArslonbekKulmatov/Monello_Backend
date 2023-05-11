package com.example.asaka.core.services;

import org.springframework.core.io.Resource;
import org.springframework.web.multipart.MultipartFile;

import java.nio.file.Path;
import java.util.Optional;

//Cr By: Arslonbek Kulmatov
//For working with files
public interface FilesStorageService {
    public void init(Path root);

    //Cr By: Arslonbek Kulmatov
    //Saving files into server directory
    public void save(MultipartFile file, String file_name, Path root);

    //Cr By: Arslonbek Kulmatov
    //Loading files
    public Resource load(String filename, Path root);

    //Cr By: Arslonbek Kulmatov
    //Deleting file from server folder
    public void delete(String file_name);

    //Cr By: Arslonbek Kulmatov
    //Getting file extension type
    public Optional<String> getExtensionByStringHandling(String filename);
}
