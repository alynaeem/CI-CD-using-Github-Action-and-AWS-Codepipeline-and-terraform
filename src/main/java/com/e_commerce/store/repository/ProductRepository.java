package com.e_commerce.store.repository;

import com.e_commerce.store.model.Product;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ProductRepository extends JpaRepository<Product, Long> {
    // Custom queries can be added here if needed
}