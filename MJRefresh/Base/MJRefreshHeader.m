//  代码地址: https://github.com/CoderMJLee/MJRefresh
//  代码地址: http://code4app.com/ios/%E5%BF%AB%E9%80%9F%E9%9B%86%E6%88%90%E4%B8%8B%E6%8B%89%E4%B8%8A%E6%8B%89%E5%88%B7%E6%96%B0/52326ce26803fabc46000000
//  MJRefreshHeader.m
//  MJRefreshExample
//
//  Created by MJ Lee on 15/3/4.
//  Copyright (c) 2015年 小码哥. All rights reserved.
//

#import "MJRefreshHeader.h"

@interface MJRefreshHeader()
@property (assign, nonatomic) CGFloat insetTDelta;
@end

@implementation MJRefreshHeader
#pragma mark - 构造方法
+ (instancetype)headerWithRefreshingBlock:(MJRefreshComponentRefreshingBlock)refreshingBlock
{
    MJRefreshHeader *cmp = [[self alloc] init];
    cmp.refreshingBlock = refreshingBlock;
    return cmp;
}
+ (instancetype)headerWithRefreshingTarget:(id)target refreshingAction:(SEL)action
{
    MJRefreshHeader *cmp = [[self alloc] init];
    [cmp setRefreshingTarget:target refreshingAction:action];
    return cmp;
}

#pragma mark - 覆盖父类的方法
//  initWithFrame时调用，这时候通过self.mj_h = MJRefreshHeaderHeight设置了高度（54.0）
- (void)prepare
{
    [super prepare];
    
    // 设置key
    self.lastUpdatedTimeKey = MJRefreshHeaderLastUpdatedTimeKey;
    
    // 设置高度
    self.mj_h = MJRefreshHeaderHeight;
}

- (void)placeSubviews
{
    //  调用layoutSubviews时会首先调用这个方法
    //  父类的实现为空，什么也不做
    [super placeSubviews];
    
    // 设置y值(当自己的高度发生改变了，肯定要重新调整Y值，所以放到placeSubviews方法中设置y值)
    //  在这里设置了自身的y值，因为在ScrollView的分类中是把自身insert到了index = 0的位置，所以自身的origin.y 是一个负值
    self.mj_y = - self.mj_h - self.ignoredScrollViewContentInsetTop;
}

/** 当scrollView的contentOffset发生改变的时候调用 */
- (void)scrollViewContentOffsetDidChange:(NSDictionary *)change
{
    //  父类的实现默认是什么也不做
    [super scrollViewContentOffsetDidChange:change];
    
    // 在刷新的refreshing状态
    if (self.state == MJRefreshStateRefreshing) {
        if (self.window == nil) return;
        
        //  发现这点代码没有什么用啊，而且还难理解，去掉之后不影响使用
        // sectionheader停留解决
        //  实际上这个offset.y(是一个负值)不仅包含了你认为的offset.y还加上了(-)self.height
        //  - self.scrollView.mj_offsetY > _scrollViewOriginalInset.top  这个是为了判断有没有拉的让self露出来
        //
//        CGFloat insetT = - self.scrollView.mj_offsetY > _scrollViewOriginalInset.top ? - self.scrollView.mj_offsetY : _scrollViewOriginalInset.top;
//        CGFloat insetT = - self.scrollView.mj_offsetY;
//        insetT = insetT > self.mj_h + _scrollViewOriginalInset.top ? self.mj_h + _scrollViewOriginalInset.top : insetT;
        CGFloat insetT = self.mj_h + _scrollViewOriginalInset.top;
        self.scrollView.mj_insetT = insetT;
        
        self.insetTDelta = _scrollViewOriginalInset.top - insetT;
//        self.insetTDelta = self.mj_h;
        return;
    }
    
    // 跳转到下一个控制器时，contentInset可能会变
     _scrollViewOriginalInset = self.scrollView.contentInset;
    
    // 当前的contentOffset
    CGFloat offsetY = self.scrollView.mj_offsetY;
    // 头部控件刚好出现的offsetY
    CGFloat happenOffsetY = - self.scrollViewOriginalInset.top;
    
    // 如果是向上滚动，则这种情况下是看不见头部控件的，直接返回
    // >= -> >
    if (offsetY > happenOffsetY) return;
    
    //  offset.y到达这个normal2pullingOffsetY,说明即将开始刷新，临界点
    CGFloat normal2pullingOffsetY = happenOffsetY - self.mj_h;
    //  这个 happenOffsetY - offsetY 是说明自身露出来多少点了
    //  eg1：happenOffsetY = -64，offsetY = -74，结果为 -64 + 74 = 10
    //  不可能出现offsetY > happenOffsetY这种情况，因为当offsetY > happenOffsetY时直接就return了（上面有代码）
    //  所以pullingPercent至少是0
    CGFloat pullingPercent = (happenOffsetY - offsetY) / self.mj_h;
    
    if (self.scrollView.isDragging) { // 如果正在拖拽，只有两种情况状态需要改变
                                        //  1.当前是普通状态，但是超过临界点，这是需要由普通状态转变成即将刷新状态
                                        //  2.当前是即将刷新状态，但是用户由往回缩了一点，这时需要由即将刷新转变为普通状态
        
        self.pullingPercent = pullingPercent;
        //  自身是普通状态，但是已经过了临界点了
        if (self.state == MJRefreshStateIdle && offsetY < normal2pullingOffsetY) {
            // 转为即将刷新状态
            self.state = MJRefreshStatePulling;
            //  自身是拖拽状态，但是没过临界点
        } else if (self.state == MJRefreshStatePulling && offsetY >= normal2pullingOffsetY) {
            // 转为普通状态
            self.state = MJRefreshStateIdle;
        }
    //  如果现在没有被拖拽，且是即将刷新状态，那么就应该开始刷新了
    } else if (self.state == MJRefreshStatePulling) {// 即将刷新 && 手松开
        // 开始刷新
        [self beginRefreshing];
    //  又没有被拖拽，又不是即将刷新且手松开，那么就是普通状态且手松开了
    //  只改变一下Percent值就行
    } else if (pullingPercent < 1) {
        self.pullingPercent = pullingPercent;
    }
}

//  设置状态
- (void)setState:(MJRefreshState)state
{
    //  如果新旧状态相同，就不用改变了，直接return
    //  如果新旧状态不同，先调用父类的setState方法：
    
    //  _state = state;
    //  加入主队列的目的是等setState:方法调用完毕、设置完文字后再去布局子控件
    //      dispatch_async(dispatch_get_main_queue(), ^{
                //[self setNeedsLayout];
    //      });
    MJRefreshCheckState
    
    // 根据状态做事情
    //  现在变成普通状态了，只有原来是刷新状态才需要做事情，如果之前是即将刷新、没有更多数据，没有什么要做的事情
    if (state == MJRefreshStateIdle) {
        //  之前不是刷新状态的话就直接ruturn
        if (oldState != MJRefreshStateRefreshing) return;
        //  如果变成刷新了，就需要保存一下刷新时间
        [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:self.lastUpdatedTimeKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        // 然后恢复inset（让可滚动区域变小、自身继续隐藏在navigationBar后边）
        [UIView animateWithDuration:MJRefreshSlowAnimationDuration animations:^{
            self.scrollView.mj_insetT += self.insetTDelta;
            
            // 自动调整透明度
            if (self.isAutomaticallyChangeAlpha) self.alpha = 0.0;
            //  动画完成后记得调整pullingPercent，如果有完成刷新要完成的block，就执行这个block
        } completion:^(BOOL finished) {
            self.pullingPercent = 0.0;
            
            if (self.endRefreshingCompletionBlock) {
                self.endRefreshingCompletionBlock();
            }
        }];
    // 如果现在变成刷新状态了
    } else if (state == MJRefreshStateRefreshing) {
        
         dispatch_async(dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:MJRefreshFastAnimationDuration animations:^{
                
                CGFloat top = self.scrollViewOriginalInset.top + self.mj_h;
                // 增加滚动区域top
                self.scrollView.mj_insetT = top;
                // 设置滚动位置
                [self.scrollView setContentOffset:CGPointMake(0, -top) animated:NO];
            } completion:^(BOOL finished) {
                [self executeRefreshingCallback];
            }];
         });
    }
}

#pragma mark - 公共方法
- (void)endRefreshing
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.state = MJRefreshStateIdle;
    });
}

- (NSDate *)lastUpdatedTime
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:self.lastUpdatedTimeKey];
}
@end
