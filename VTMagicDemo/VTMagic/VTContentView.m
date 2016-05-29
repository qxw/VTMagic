//
//  VTContentView.m
//  VTMagicView
//
//  Created by tianzhuo on 14/12/29.
//  Copyright (c) 2014年 tianzhuo. All rights reserved.
//

#import "VTContentView.h"

@interface VTContentView()

@property (nonatomic, strong) NSMutableDictionary *visibleDict; // 屏幕上可见的控制器
@property (nonatomic, strong) NSMutableArray *indexList; // 索引集合
@property (nonatomic, strong) NSMutableDictionary *cacheDict; // 缓存池
@property (nonatomic, strong) NSMutableArray *frameList; // 控制器的坐标集合
@property (nonatomic, strong) NSString *identifier; // 重用标识符
@property (nonatomic, assign) NSInteger preIndex;

@end

@implementation VTContentView

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat offset = self.contentOffset.x;
    CGFloat width = self.frame.size.width;
    BOOL isNotBorder = 0 != (int)offset%(int)width;
    NSInteger currentPage = self.contentOffset.x/self.frame.size.width;
    if (_preIndex == currentPage && isNotBorder) return;
    _preIndex = currentPage;
    
    CGRect frame = CGRectZero;
    UIViewController *viewController = nil;
    NSArray *pathList = [_visibleDict allKeys];
    for (NSIndexPath *indexPath in pathList) {
        frame = [_frameList[indexPath.row] CGRectValue];
        // 控制器若移出屏幕则将其视图从父类中移除，并添加到缓存池中
        if (![self isNeedDisplayWithFrame:frame]) {
            viewController = _visibleDict[indexPath];
            [viewController.view removeFromSuperview];
            [_visibleDict removeObjectForKey:indexPath];
            
            // 添加到缓存池
            NSMutableSet *cacheSet = _cacheDict[viewController.restorationIdentifier];
            if (!cacheSet) cacheSet = [[NSMutableSet alloc] init];
            [cacheSet addObject:viewController];
            [_cacheDict setValue:cacheSet forKey:viewController.restorationIdentifier];
        }
    }
    
    NSMutableArray *tempPaths = [_indexList mutableCopy];
    [tempPaths removeObjectsInArray:pathList];
    for (NSIndexPath *indexPath in tempPaths) {
        frame = [_frameList[indexPath.row] CGRectValue];
        if ([self isNeedDisplayWithFrame:frame]) {
            viewController = [_dataSource contentView:self viewControllerForIndex:indexPath.row];
            if (!viewController) continue;
            viewController.view.frame = frame;
            viewController.restorationIdentifier = _identifier;
            [self addSubview:viewController.view];
            [_visibleDict setObject:viewController forKey:indexPath];
        }
    }
}

#pragma mark 判断指定frame是否在屏幕范围之内
- (BOOL)isNeedDisplayWithFrame:(CGRect)frame
{
    CGFloat referenceMinX = self.contentOffset.x;
    CGFloat referenceMaxX = referenceMinX + self.frame.size.width;
    CGFloat viewMinX = frame.origin.x;
    CGFloat viewMaxX = viewMinX + frame.size.width;
    BOOL isLeftBorderInScreen = referenceMinX <= viewMinX && viewMinX <= referenceMaxX;
    BOOL isRightBorderInScreen = referenceMinX <= viewMaxX && viewMaxX <= referenceMaxX;
    BOOL isInScreen = isLeftBorderInScreen || isRightBorderInScreen;
    return isInScreen;
}

#pragma mark - 加载数据
- (void)reloadData
{
    [self resetCacheData];
    [self resetFrames];
    [self setNeedsLayout];
}

- (void)layoutSubviewsWhenRotated
{
    [self resetFrames];
}

#pragma mark - 重置缓存信息
-(void)resetCacheData
{
    if (!_frameList) {
        _frameList = [[NSMutableArray alloc] initWithCapacity:_pageCount];
    } else {
        [_frameList removeAllObjects];
    }
    
    if (!_indexList) {
        _indexList = [[NSMutableArray alloc] initWithCapacity:_pageCount];
    } else {
        [_indexList removeAllObjects];
    }
    
    for (NSInteger i = 0; i < _pageCount; i++) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
        [_indexList addObject:indexPath];
    }
    
    if (!_cacheDict) {
        _cacheDict = [[NSMutableDictionary alloc] initWithCapacity:_pageCount];
    }
    
    if (!_visibleDict) {
        _visibleDict = [[NSMutableDictionary alloc] initWithCapacity:_pageCount];
    }
}

- (void)resetFrames
{
    [_frameList removeAllObjects];
    CGRect frame = self.bounds;
    for (NSIndexPath *indexPath in _indexList) {
        frame.origin.x = indexPath.row * frame.size.width;
        [_frameList addObject:[NSValue valueWithCGRect:frame]];
    }
    self.contentSize = CGSizeMake(CGRectGetMaxX([[_frameList lastObject] CGRectValue]), 0);
}

#pragma mark - accessor
- (NSArray *)visibleList
{
    return [_visibleDict allValues];
}

- (UIViewController *)viewControllerWithIndex:(NSInteger)index
{
    return [self viewControllerWithIndex:index autoCreateForNil:NO];
}

- (UIViewController *)viewControllerWithIndex:(NSInteger)index autoCreateForNil:(BOOL)autoCreate
{
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
    UIViewController *viewController = [_visibleDict objectForKey:indexPath];
    if (!viewController && autoCreate) {
        viewController = [_dataSource contentView:self viewControllerForIndex:index];
        viewController.restorationIdentifier = _identifier;
        if (!viewController) return viewController;
        viewController.view.frame = [_frameList[indexPath.row] CGRectValue];
        [self addSubview:viewController.view];
        [_visibleDict setObject:viewController forKey:indexPath];
    }
    
    return viewController;
}

#pragma mark - 根据缓存标识查询可重用的视图控制器
- (id)dequeueReusableViewControllerWithIdentifier:(NSString *)identifier
{
    _identifier = identifier;
    NSMutableSet *cacheSet = _cacheDict[identifier];
    UIViewController *viewController = [cacheSet anyObject];
    if (viewController) {
        [cacheSet removeObject:viewController];
        [_cacheDict setValue:cacheSet forKey:identifier];
    }
    return viewController;
}

@end