using Printf

# Companion code for PagedOut! "Iterating over floats" article.
# The code demonstrates some non-intuitive float results. The
# code also re-implements Java's previously incorrect round()
# function and shows all the cases where the function returns
# an incorrect value by comparing it to a slower version of
# round().

# Show some non-intuituive float results
function non_intuitive_results()
    print("Adding 0.5:\n")
    a = 4503599627370497.0
    b = a + 0.5
    @printf("%0.3f\t%0.3f\t%0.3f\n\n", a, b, b-a)

    x = 1e16
    y = -x
    z = 1
    @printf("(x+y)+z:\t%0.3f\nx+(y+z):\t%0.3f\n\n", (x+y)+z, x+(y+z))
end

# For every possible Float16, check if bad_round() and slow_round() differ
function test_all_floats()
    all_whole_floats = whole_floats()
    for bits = 0x0000:0xffff
        f = reinterpret(Float16, UInt16(bits))
        r1 = bad_round(f)
        r2 = slow_round(f, all_whole_floats)
        if isnan(r1) && isnan(r2)
            continue
        end
        if r1 != r2
            @printf("Possible bug! f=%f, bad_round=%0.3f, slow_round=%0.3f\n", f, r1, r2)
        end
    end
end

# Implementation of Java's previously incorrect round function
function bad_round(n)
    return floor(n + Float16(0.5))
end


# Slow round function which compares the distance between n and
# every whole float. Assumes floating point subtraction, abs(),
# isnan(), and isinf() are implemented correctly.
function slow_round(n::Float16, all_whole_floats::Vector{Float16})
    if isinf(n)
        return n
    end
    best_delta = Inf
    best_value = NaN
    for f in all_whole_floats
        d = abs(f - n)
        if d < best_delta
            best_delta = d
            best_value = f
        elseif d == best_delta
            if isnan(best_value) || (f > best_value)
                best_delta = d
                best_value = f
            end
        end
    end
    return best_value
end


# Checks if a float bit pattern corresponds to a whole number
function is_whole(bits::UInt16)
    # Exponent (bits 14-10, 5 bits)
    exponent_bits = (bits >> 10) & 0x001f
    if exponent_bits == 0x1f
        # All exponent bits are 1, we either have Inf or NaN
        return false
    end
  
    # Mantissa/Significand (bits 9-0, 10 bits)
    mantissa_bits = bits & 0x03ff
  
    # Handle zero (both +0 and -0 are whole numbers)
    if exponent_bits == 0 && mantissa_bits == 0
        return true
    end
  
    # Handle subnormal numbers (exponent = 0, mantissa ≠ 0)
    # These are very small numbers, none are whole except
    # zero, which we already handled
    if exponent_bits == 0
        return false
    end
  
    # Calculate the actual exponent (remove bias of 15)
    actual_exponent = Int(exponent_bits) - 15
  
    # For a number to be whole, we need the fractional part to be zero
    # The mantissa represents the fractional part after the implicit leading 1
    # We need to check if all fractional bits are zero
    if actual_exponent < 0
        # If exponent is negative, the number is between -1 and 1 (exclusive)
        # Only ±0 can be whole, which we already handled
        return false
    elseif actual_exponent >= 10
        # If exponent >= 10, all mantissa bits represent whole number part
        # No fractional bits remain, so it's definitely a whole number
        return true
    else
        # actual_exponent is between 0 and 9
        # Check if the fractional part is zero
        # The number of fractional bits is (10 - actual_exponent)
        fractional_bits = 10 - actual_exponent
      
        # Create a mask for the fractional bits
        fractional_mask = (1 << fractional_bits) - 1
      
        # Check if all fractional bits are zero
        return (mantissa_bits & fractional_mask) == 0
    end
end

# Return a vector of floats which are whole numbers
function whole_floats()
   r = Float16[]
   for bits = 0x0000:0xffff
       if !is_whole(UInt16(bits))
           continue
       end
       f = reinterpret(Float16, UInt16(bits))
       push!(r, f)
   end
   return r
end

non_intuitive_results()
test_all_floats()

println("Done")
