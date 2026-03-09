package com.e_commerce.store.service.impl;

import com.e_commerce.store.dto.ProductDTO;
import com.e_commerce.store.mapper.ProductMapper;
import com.e_commerce.store.model.Product;
import com.e_commerce.store.repository.ProductRepository;
import com.e_commerce.store.service.ProductService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class ProductServiceImpl implements ProductService {

    private final ProductRepository productRepository;
    private final ProductMapper productMapper;

    public ProductServiceImpl(ProductRepository productRepository,
                              ProductMapper productMapper) {
        this.productRepository = productRepository;
        this.productMapper = productMapper;
    }

    @Override
    @Transactional
    public ProductDTO createProduct(ProductDTO productDTO) {
        Product product = productMapper.productDTOToProduct(productDTO);
        product = productRepository.save(product);
        return productMapper.productToProductDTO(product);
    }

    @Override
    @Transactional
    public ProductDTO getProductById(Long id) {
        Product product = productRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Product not found"));
        return productMapper.productToProductDTO(product);
    }

    @Override
    @Transactional
    public ProductDTO updateProduct(ProductDTO productDTO) {
        Product existingProduct = productRepository.findById(productDTO.getId())
                .orElseThrow(() -> new IllegalArgumentException("Product not found"));

        existingProduct.setName(productDTO.getName());
        existingProduct.setPrice(productDTO.getPrice());
        existingProduct.setDescription(productDTO.getDescription());
        existingProduct.setStockQuantity(productDTO.getStockQuantity());

        existingProduct = productRepository.save(existingProduct);
        return productMapper.productToProductDTO(existingProduct);
    }

    @Override
    @Transactional
    public void deleteProduct(Long id) {
        if (!productRepository.existsById(id)) {
            throw new IllegalArgumentException("Product not found");
        }
        productRepository.deleteById(id);
    }

    @Override
    public List<ProductDTO> getAllProducts() {
        return productRepository.findAll().stream()
                .map(productMapper::productToProductDTO)
                .toList();
    }
}