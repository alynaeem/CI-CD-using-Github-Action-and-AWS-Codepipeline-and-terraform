package com.e_commerce.store.service;

import com.e_commerce.store.dto.ProductDTO;

import java.util.List;

public interface ProductService {

    ProductDTO createProduct(ProductDTO productDTO);
    ProductDTO getProductById(Long id);
    ProductDTO updateProduct(ProductDTO productDTO);
    void deleteProduct(Long id);
    List<ProductDTO> getAllProducts();
}
