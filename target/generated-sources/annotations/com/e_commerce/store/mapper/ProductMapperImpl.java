package com.e_commerce.store.mapper;

import com.e_commerce.store.dto.ProductDTO;
import com.e_commerce.store.model.Product;
import javax.annotation.processing.Generated;
import org.springframework.stereotype.Component;

@Generated(
    value = "org.mapstruct.ap.MappingProcessor",
    date = "2026-03-09T16:27:51+0500",
    comments = "version: 1.5.5.Final, compiler: javac, environment: Java 18 (Oracle Corporation)"
)
@Component
public class ProductMapperImpl implements ProductMapper {

    @Override
    public ProductDTO productToProductDTO(Product product) {
        if ( product == null ) {
            return null;
        }

        ProductDTO productDTO = new ProductDTO();

        productDTO.setId( product.getId() );
        productDTO.setName( product.getName() );
        productDTO.setPrice( product.getPrice() );
        productDTO.setDescription( product.getDescription() );
        productDTO.setStockQuantity( product.getStockQuantity() );

        return productDTO;
    }

    @Override
    public Product productDTOToProduct(ProductDTO productDTO) {
        if ( productDTO == null ) {
            return null;
        }

        Product.ProductBuilder product = Product.builder();

        product.name( productDTO.getName() );
        if ( productDTO.getPrice() != null ) {
            product.price( productDTO.getPrice() );
        }
        product.description( productDTO.getDescription() );
        product.stockQuantity( productDTO.getStockQuantity() );

        return product.build();
    }
}
