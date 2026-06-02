#import "OrbitIconRenderer.h"

@implementation OrbitIconRenderer

+ (UIImage*)orbitConsoleIconWithSize:(CGSize)size {
    UIGraphicsImageRendererFormat* format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = YES;
    format.scale = 1.0;

    UIGraphicsImageRenderer* renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext* context) {
        CGContextRef cg = context.CGContext;
        CGRect bounds = CGRectMake(0.0, 0.0, size.width, size.height);

        [[UIColor colorWithRed:0.0 green:0.102 blue:0.20 alpha:1.0] setFill];
        CGContextFillRect(cg, bounds);

        CGPoint center = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
        CGFloat radius = MIN(size.width, size.height) * 0.23;
        CGRect circleRect = CGRectMake(center.x - radius, center.y - radius, radius * 2.0, radius * 2.0);

        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        NSArray* silverColors = @[
            (__bridge id)[UIColor colorWithWhite:0.95 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithWhite:0.58 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithWhite:0.98 alpha:1.0].CGColor,
        ];
        CGFloat silverStops[] = {0.0, 0.52, 1.0};
        CGGradientRef silver = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)silverColors, silverStops);

        CGContextSaveGState(cg);
        UIBezierPath* circle = [UIBezierPath bezierPathWithOvalInRect:circleRect];
        [circle addClip];
        CGContextDrawLinearGradient(cg, silver, CGPointMake(CGRectGetMinX(circleRect), CGRectGetMinY(circleRect)),
                                    CGPointMake(CGRectGetMaxX(circleRect), CGRectGetMaxY(circleRect)), 0);
        CGContextRestoreGState(cg);

        UIBezierPath* orbit = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(bounds, size.width * 0.16, size.height * 0.36)];
        CGAffineTransform rotate = CGAffineTransformMakeTranslation(-center.x, -center.y);
        rotate = CGAffineTransformRotate(rotate, (CGFloat)M_PI_4);
        rotate = CGAffineTransformTranslate(rotate, center.x, center.y);
        [orbit applyTransform:rotate];
        orbit.lineWidth = MAX(5.0, size.width * 0.035);
        [[UIColor colorWithWhite:0.88 alpha:0.92] setStroke];
        [orbit stroke];

        UIBezierPath* highlight = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(circleRect, radius * 0.38, radius * 0.38)];
        [[UIColor colorWithWhite:1.0 alpha:0.18] setFill];
        [highlight fill];

        CGGradientRelease(silver);
        CGColorSpaceRelease(colorSpace);
    }];
}

@end
