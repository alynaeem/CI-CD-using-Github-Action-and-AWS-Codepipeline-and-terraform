package com.e_commerce.store.mapper;

import com.e_commerce.store.dto.ProductDTO;
import com.e_commerce.store.model.Product;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

@Mapper(componentModel = "spring")
public interface ProductMapper {
    // No need for componentModel here since we set it globally
    ProductDTO productToProductDTO(Product product);

    @Mapping(target = "id", ignore = true) // Example of specific mapping
    Product productDTOToProduct(ProductDTO productDTO);
}