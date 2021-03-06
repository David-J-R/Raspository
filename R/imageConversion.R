#' Title
#'
#' @param H
#' @param C
#' @param X
#' @param m
#'
#' @return
#' @export
#'
#' @examples
calculateRGBvalue <- function(H, C, X, m){
   if(H >= 0 && H <= 1){
       return(c(m + C, m + X, m))
   }else if(H >= 0 && H <= 2){
       return(c(m + X, m + C, m))
   }else if(H >= 0 && H <= 3){
       return(c(m, m + C, m + X))
   }else if(H >= 0 && H <= 4){
       return(c(m, m + X, m + C))
   }else if(H >= 0 && H <= 5){
       return(c(m + X, m, m + C))
   }else if(H >= 0 && H <= 6){
       return(c(m + C, m, m + X))
   }else{
       return(c(0,0,0))
   }
}


#' Title
#'
#' @param hsvArray
#'
#' @return
#' @export
#' @importFrom abind abind
#'
#' @examples
hsvArrayToRgb <- function(hsvArray){

    # Calculate the chroma
    C <- hsvArray[,,3] * hsvArray[,,2]

    H<- hsvArray[,,1] / 60

    X <-  C * (1 - abs(H %% 2 - 1))

    #https://en.wikipedia.org/wiki/HSL_and_HSV#HSV_to_RGB
    m <- hsvArray[,,3] - C
    rgb<-mapply(FUN = calculateRGBvalue, H = H, C = C, X = X, m = m)

    rgbArray<-abind(matrix(rgb[1,], nrow = nrow(hsvArray)),
                matrix(rgb[2,], nrow = nrow(hsvArray)),
                matrix(rgb[3,], nrow = nrow(hsvArray)),
                along = 3)


    return(rgbArray)
}

#' Title
#'
#' @param img
#'
#' @return
#' @export
#'
#' @examples
imageRGBFromHSV <- function(img){
    return(new("imageRGB", image = hsvArrayToRgb(img@imageMatrix)))
}

#' Title
#'
#' @param img
#' @param chPortion
#'
#' @return
#' @export
#'
#' @examples
imageOneChannelFromRGB <- function(img, chPortion = c(0.33, 0.33, 0.33)){
    if(sum(chPortion) > 1){
        stop("Channel portions mustn't add up to more than one.")
    }
    current <- img@imageArray[,,1] * chPortion[1] + 
        img@imageArray[,,2] * chPortion[2] + img@imageArray[,,3] * chPortion[3]
    return(new("imageOneChannel", imageMatrix = current))
}

#' Title
#'
#' @param max
#' @param maxIndex
#' @param min
#' @param r
#' @param g
#' @param b
#'
#' @return
#' @export
#'
#' @references \insertRef{Weickert2019}{Raspository}
#'
#' @examples
calculateHUE <- function(max, maxIndex, min, r, g, b){
    h <- 0.0
    if(max == min){
        return(h)
    }else if(maxIndex == 1){
        h <- 60.0 * ((g - b)/(max - min))
    }else if(maxIndex == 2){
        h <- 60.0 * (2.0 + (b - r)/(max - min))
    }else if(maxIndex == 3){
        h <- 60.0 * (4.0 + (r - g)/(max - min))
    }

    # if the value is negativ add 360° to it
    if(h >= 0){
        return(h)
    }else{
        return(h + 360)
    }
}

#' Title
#'
#' @param rgbArray
#'
#' @return
#' @export
#' @importFrom abind abind
#'
#' @references \insertRef{Weickert2019}{Raspository}
#'
#' @examples
rgbArrayToHsv <- function(rgbArray){
    # get the maximal color and its index in each pixel
    max <- apply(rgbArray, c(1,2), max)
    maxIndex <-apply(rgbArray, c(1,2), which.max)
    # get the minimal color in each pixel
    min <- apply(rgbArray, c(1,2), min)

    # calculate the hue for each pixel
    h <- mapply(FUN = calculateHUE, max = max, maxIndex = maxIndex, min = min,
                r = rgbArray[,,1], g = rgbArray[,,2], b = rgbArray[,,3])
    # convert vector back to matrix
    h <- matrix(h, ncol = ncol(max))

    # calculate saturation
    s <- (max - min)/max
    # set values to zero, where max is 0 (division by zero -> NA)
    s[is.na(s)] <- 0
    # max is equal to v (value/brightness)
    v <- max

    # bind matrices together to array and return
    hsvArray <- abind(h, s, v, along = 3)
    return(hsvArray)
}

#' Title
#'
#' @param img
#'
#' @return
#' @export
#'
#' @references \insertRef{Weickert2019}{Raspository}
#'
#' @examples
imageHSVFromRGB <- function(img){
    return(new("imageHSV", image = rgbArrayToHsv(img@imageArray)))
}


#' Title
#'
#' @param img
#' @param transformPaletteFunction
#' @param method
#'
#' @return
#' @export
#'
#' @references \insertRef{Floyd}{Raspository}
#' @references \insertRef{Jarvis1976}{Raspository}
#'
#' @examples
errorDiffusiondDithering <- function(img, transformPaletteFunction = round,
                                     method = c("FS", "mae")){
    image <- img@imageMatrix
    imageTmp <- image
    
    if(method[1] == "FS"){
        imageTmp <- fsDithering(img = imageTmp, transformPaletteFunction = transformPaletteFunction)
    }else if(method[1] == "mea"){
        imageTmp <- meaDithering(img = imageTmp, transformPaletteFunction = transformPaletteFunction)
    }

    ditheredImage <- new(class(img)[[1]], image = imageTmp)

    return(cropPixels(ditheredImage))
}


#' Lattice Boltzman Dithering
#'
#' @param img 
#' @param epsilon 
#' @param minimalTreshold 
#'
#' @return
#' @export
#' 
#' @references \insertRef{Hagenburg2009}{Raspository}
#'
#' @examples
lbDithering <- function(img, epsilon = 0.5, minimalTreshold = 0.01){
    
    i <- 0
    difference <-epsilon + 1
    while(difference > epsilon){
        imgAtNewStep <- dissipatePixel(img = img, minimalTreshold = minimalTreshold)
        
        difference <- norm(imgAtNewStep - img, type = "2")
        #print(difference)
        
        img <- imgAtNewStep

        i <- i +1
    }
    
    return(round(img))
}
