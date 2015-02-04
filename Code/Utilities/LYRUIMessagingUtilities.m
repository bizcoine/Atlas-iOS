//
//  LYRUIMessagingUtilities.m
//  LayerUIKit
//
//  Created by Kevin Coleman on 10/27/14.
//
//

#import "LYRUIMessagingUtilities.h"
#import "LYRUIErrors.h"
#import <AssetsLibrary/AssetsLibrary.h>

NSString *const LYRUIMIMETypeTextPlain = @"text/plain";
NSString *const LYRUIMIMETypeTextHTML = @"text/HTML";
NSString *const LYRUIMIMETypeImagePNG = @"image/png";
NSString *const LYRUIMIMETypeImageSize = @"application/json+imageSize";
NSString *const LYRUIMIMETypeImageJPEG = @"image/jpeg";
NSString *const LYRUIMIMETypeImageJPEGPreview = @"image/jpeg+preview";
NSString *const LYRUIMIMETypeLocation = @"location/coordinate";
NSString *const LYRUIMIMETypeDate = @"text/date";

NSString *const LYRUIImagePreviewWidthKey = @"width";
NSString *const LYRUIImagePreviewHeightKey = @"height";
NSString *const LYRUILocationLatitudeKey = @"latitude";
NSString *const LYRUILocationLongitudeKey = @"longitude";

#pragma mark - Max Cell Dimensions

CGFloat LYRUIMaxCellWidth()
{
    return 220;
}

CGFloat LYRUIMaxCellHeight()
{
    return 300;
}

#pragma mark - Private Image Utilities

CGSize LYRUISizeProportionallyConstrainedToSize(CGSize nativeSize, CGSize maxSize)
{
    CGSize itemSize;
    CGFloat widthScale = maxSize.width / nativeSize.width;
    CGFloat heightScale = maxSize.height / nativeSize.height;
    if (heightScale < widthScale) {
        itemSize = CGSizeMake(nativeSize.width * heightScale, maxSize.height);
    } else {
        itemSize = CGSizeMake(maxSize.width, nativeSize.height * widthScale);
    }
    return itemSize;
}

UIImage *LYRUIAdjustOrientationForImage(UIImage *originalImage)
{
    UIGraphicsBeginImageContextWithOptions(originalImage.size, NO, originalImage.scale);
    [originalImage drawInRect:(CGRect){0, 0, originalImage.size}];
    UIImage *fixedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return fixedImage;
}

#pragma mark - Image Utilities

CGSize LYRUIImageSizeForData(NSData *data)
{
    UIImage *image = [UIImage imageWithData:data];
    return LYRUIImageSize(image);
}

CGSize LYRUIImageSizeForJSONData(NSData *data)
{
    NSDictionary *sizeDictionary = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
    CGFloat width = [sizeDictionary[LYRUIImagePreviewWidthKey] floatValue];
    CGFloat height = [sizeDictionary[LYRUIImagePreviewHeightKey] floatValue];
    return CGSizeMake(width, height);
}

CGSize LYRUIImageSize(UIImage *image)
{
    CGSize maxSize = CGSizeMake(LYRUIMaxCellWidth(), LYRUIMaxCellHeight());
    CGSize itemSize = LYRUISizeProportionallyConstrainedToSize(image.size, maxSize);
    return itemSize;
}

CGSize LYRUITextPlainSize(NSString *text, UIFont *font)
{
    CGRect rect = [text boundingRectWithSize:CGSizeMake(LYRUIMaxCellWidth(), CGFLOAT_MAX)
                                     options:NSStringDrawingUsesLineFragmentOrigin
                                  attributes:@{NSFontAttributeName: font}
                                     context:nil];
    return rect.size;
}

CGRect LYRUIImageRectConstrainedToSize(CGSize imageSize, CGSize maxSize)
{
    CGSize itemSize = LYRUISizeProportionallyConstrainedToSize(imageSize, maxSize);
    CGRect thumbRect = {0, 0, itemSize};
    return thumbRect;
}

#pragma mark - Private Message Part Helpers

NSData *LYRUIJPEGDataForImageWithConstraint(UIImage *image, CGFloat constraint, CGFloat quality)
{
    NSData *pngData = UIImagePNGRepresentation(image);
    CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)pngData, NULL);
    CGImageRef resizedImage = CGImageSourceCreateThumbnailAtIndex(source, 0, (CFDictionaryRef)@{ (NSString *)kCGImageSourceThumbnailMaxPixelSize: @(constraint),
                                                                                                 (NSString *)kCGImageSourceCreateThumbnailFromImageIfAbsent: @(YES) });
    UIImage *resizedUIImage = [UIImage imageWithCGImage:resizedImage];
    return UIImageJPEGRepresentation(resizedUIImage, quality);
}

CGSize  LYRUISizeFromOriginalSizeWithConstraint(CGSize originalSize, CGFloat constraint)
{
    if (originalSize.height > constraint && (originalSize.height > originalSize.width)) {
        CGFloat heightRatio = constraint / originalSize.height;
        return CGSizeMake(originalSize.width * heightRatio, constraint);
    } else if (originalSize.width > constraint) {
        CGFloat widthRatio = constraint / originalSize.width;
        return CGSizeMake(constraint, originalSize.height * widthRatio);
    }
    return originalSize;
}

#pragma mark - Message Parts Constructors

LYRMessagePart *LYRUIMessagePartWithText(NSString *text)
{
    return [LYRMessagePart messagePartWithMIMEType:@"text/plain" data:[text dataUsingEncoding:NSUTF8StringEncoding]];
}

LYRMessagePart *LYRUIMessagePartWithJPEGImage(UIImage *image, BOOL isPreview)
{
    UIImage *adjustedImage = LYRUIAdjustOrientationForImage(image);
    NSData *imageData;
    if (isPreview) {
        imageData = LYRUIJPEGDataForImageWithConstraint(adjustedImage, 768, 0.8f);
    } else {
        imageData = UIImageJPEGRepresentation(adjustedImage, 0.8f);
    }
    return [LYRMessagePart messagePartWithMIMEType:isPreview ? LYRUIMIMETypeImageJPEGPreview : LYRUIMIMETypeImageJPEG
                                              data:imageData];
}

LYRMessagePart *LYRUIMessagePartForImageSize(UIImage *image)
{
    CGSize size = LYRUIImageSize(image);
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@{LYRUIImagePreviewWidthKey : @(size.width), LYRUIImagePreviewHeightKey : @(size.height)}
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:nil];
    return [LYRMessagePart messagePartWithMIMEType:LYRUIMIMETypeImageSize data:jsonData];
}

LYRMessagePart *LYRUIMessagePartWithLocation(CLLocation *location)
{
    NSNumber *lat = @(location.coordinate.latitude);
    NSNumber *lon = @(location.coordinate.longitude);
    NSData *data = [NSJSONSerialization dataWithJSONObject:@{LYRUILocationLatitudeKey: lat, LYRUILocationLongitudeKey: lon} options:0 error:nil];
    return [LYRMessagePart messagePartWithMIMEType:LYRUIMIMETypeLocation data:data];
}

#pragma mark - Image Capture Utilities

void LYRUILastPhotoTaken(void(^completionHandler)(UIImage *image, NSError *error))
{
    // Credit goes to @iBrad Apps on Stack Overflow
    // http://stackoverflow.com/questions/8867496/get-last-image-from-photos-app
    
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    
    // Enumerate just the photos and videos group by using ALAssetsGroupSavedPhotos.
    [library enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        // When done, the group enumeration block is called another time with group set to nil.
        if (!group) return;

        // Within the group enumeration block, filter to enumerate just photos.
        [group setAssetsFilter:[ALAssetsFilter allPhotos]];

        if ([group numberOfAssets] == 0) {
            completionHandler(nil, [NSError errorWithDomain:LYRUIErrorDomain code:LYRUIErrorNoPhotos userInfo:@{NSLocalizedDescriptionKey: @"There are no photos."}]);
            return;
        }
        
        [group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:^(ALAsset *result, NSUInteger index, BOOL *innerStop) {
            // When done, the asset enumeration block is called another time with result set to nil.
            if (!result) return;

            ALAssetRepresentation *representation = [result defaultRepresentation];
            UIImage *latestPhoto = [UIImage imageWithCGImage:[representation fullScreenImage]];
            
            // Stop the enumerations
            *innerStop = YES;
            *stop = YES;
            completionHandler(latestPhoto, nil);
        }];
    } failureBlock:^(NSError *error) {
        completionHandler(nil, error);
    }];
}

UIImage *LYRUIPinPhotoForSnapshot(MKMapSnapshot *snapshot, CLLocationCoordinate2D location)
{
    // Create a pin image.
    MKAnnotationView *pin = [[MKPinAnnotationView alloc] initWithAnnotation:nil reuseIdentifier:@""];
    UIImage *pinImage = pin.image;
    
    // Draw the image.
    UIImage *image = snapshot.image;
    UIGraphicsBeginImageContextWithOptions(image.size, YES, image.scale);
    [image drawAtPoint:CGPointMake(0, 0)];
    
    // Draw the pin.
    CGPoint point = [snapshot pointForCoordinate:location];
    [pinImage drawAtPoint:CGPointMake(point.x, point.y - pinImage.size.height)];
    UIImage *finalImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return finalImage;
}

NSArray *LYRUILinkResultsForText(NSString *text)
{
    if (!text) return nil;
    
    NSError *error;
    NSDataDetector *detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink
                                                               error:&error];
    if (error) return nil;
    return [detector matchesInString:text options:kNilOptions range:NSMakeRange(0, text.length)];
}
