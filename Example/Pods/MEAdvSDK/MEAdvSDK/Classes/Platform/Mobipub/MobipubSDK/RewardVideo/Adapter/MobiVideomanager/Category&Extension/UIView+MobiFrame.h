//
//  UIView+Frame.h
//  Mobi_Vedio
//
//  Created by 李新丰 on 2020/7/29.
//  Copyright © 2020 李新丰. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIView (MobiFrame)
/** 坐标 origin */
@property (nonatomic, assign) CGPoint origin;
/** 坐标 size */
@property (nonatomic, assign) CGSize size;

/** 坐标 width */
@property (nonatomic, assign) CGFloat width;
/** 坐标 height */
@property (nonatomic, assign) CGFloat height;

/** 坐标 x */
@property (nonatomic, assign) CGFloat x;
/** 坐标 y */
@property (nonatomic, assign) CGFloat y;
/** 坐标 maxX */
@property (nonatomic, assign) CGFloat maxX;
/** 坐标 maxY */
@property (nonatomic, assign) CGFloat maxY;
/** 坐标 centerX */
@property (nonatomic, assign) CGFloat centerX;
/** 坐标 centerY */
@property (nonatomic, assign) CGFloat centerY;

@end

NS_ASSUME_NONNULL_END
