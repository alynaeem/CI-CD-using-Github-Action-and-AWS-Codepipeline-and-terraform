package com.e_commerce.store.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import lombok.Data;

@Data
public class ProductDTO {

    private Long id;

    @NotBlank(message = "Product name is required")
    private String name;

    @NotNull(message = "Price is required")
    @PositiveOrZero(message = "Price must be zero or positive")
    private Double price;

    private String description;

    @Min(value = 0, message = "Stock quantity must be zero or positive")
    private int stockQuantity;
}