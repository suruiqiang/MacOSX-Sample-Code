//
//  CustomArrayController.m
//  SimpleCap
//
//  Created by Hiroshi Hashiguchi on 10/12/27.
//  Copyright 2010 . All rights reserved.
//

#import "CustomArrayController.h"
#import <objc/runtime.h>

@interface CustomArrayController ()
@property (nonatomic, retain) NSUndoManager* undoManager;

@end


@implementation CustomArrayController

@synthesize undoManager = undoManager_;
@synthesize keys = keys_;


#pragma mark -
#pragma mark Private utilities
- (NSArray*)_propertyListOfClass:(Class)clz
{
	NSMutableArray* list = [NSMutableArray array];
	unsigned int outCount, i;
	objc_property_t *properties = class_copyPropertyList(clz, &outCount);
	
	for(i = 0; i < outCount; i++) {
		objc_property_t property = properties[i];
		const char *propName = property_getName(property);
		NSString *propertyName = [NSString stringWithUTF8String:propName];
		[list addObject:propertyName];
	}
	free(properties);
	return list;
}


- (void)_setArrangedObject:(id)object value:(id)value forKeyPath:(NSString*)keyPath
{
		// "<null>" -> NSNull
	
	id currentValue = [object valueForKey:keyPath];
	
	[[self.undoManager prepareWithInvocationTarget:self]
	 _setArrangedObject:object value:currentValue forKeyPath:keyPath];	
	
	[object setValue:value forKeyPath:keyPath];
}


#pragma mark -
#pragma mark KVO callback
- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
	if (change) {
				NSLog(@"keyPath: %@, change: %@", keyPath, change);
		id value = [change objectForKey:NSKeyValueChangeOldKey];
		if (value == [NSNull null]) {
			value = nil;
		}
		[[self.undoManager prepareWithInvocationTarget:self]
		 _setArrangedObject:object value:value forKeyPath:keyPath];			
	}
}

#pragma mark -
#pragma mark Initialization and Deallocation
- (void)_setup
{
	self.undoManager = [[[NSUndoManager alloc] init] autorelease];
	self.keys = [self _propertyListOfClass:[self objectClass]];
}

- (id) init
{
	self = [super init];
	if (self != nil) {
		[self _setup];
	}
	return self;
}


- (id)initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder:aDecoder];
	if (self != nil) {
		[self _setup];
	}
	return self;
}

- (void) dealloc
{
	self.undoManager = nil;
	[super dealloc];
}


#pragma mark -
#pragma mark Overridden methods
- (void)setObjectClass:(Class)objectClass
{
	[super setObjectClass:objectClass];
	self.keys = [self _propertyListOfClass:objectClass];
}
/*
- (void)addObject:(id)object
{
	NSLog(@"-------------------------------------------");
	NSLog(@"%s|%@", __PRETTY_FUNCTION__, object);

	NSInteger count = [[self arrangedObjects] count];
	NSIndexSet* indexes = [NSIndexSet indexSetWithIndex:count];
	[self _insertObjects:[NSArray arrayWithObject:object]
										atIndexes:indexes];
	[super addObject:object];
}

- (void)addObjects:(NSArray *)objects
{
	NSLog(@"-------------------------------------------");
	NSLog(@"%s|%@", __PRETTY_FUNCTION__, objects);
	
	NSInteger count = [[self arrangedObjects] count];
	NSIndexSet* indexes = [NSIndexSet indexSetWithIndexesInRange:
						   NSMakeRange(count, [objects count])];
	[self _insertObjects:objects atIndexes:indexes];
	
	[super addObjects:objects];
}
*/


- (void)_addObserverFor:(NSArray*)objects
{
	for (id object in objects) {
		NSArray* keys = self.keys;
		for (NSString* key in keys) {
			[object addObserver:self
					 forKeyPath:key
						options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld
						context:nil];			
		}
	}
}

- (void)_removeObserverFor:(NSArray*)objects
{
	for (id object in objects) {
		NSArray* keys = self.keys;
		for (NSString* key in keys) {
			[object removeObserver:self
						forKeyPath:key];
		}
	}
	
}

- (void)setContent:(id)content
{
	[self _addObserverFor:content];
	[super setContent:content];
}

- (void)addObject:(id)object
{
	NSLog(@"%s|%@", __PRETTY_FUNCTION__, object);
	[super addObject:object];
}

- (void)addObjects:(NSArray *)objects
{
	NSLog(@"%s|%@", __PRETTY_FUNCTION__, objects);
	[super addObjects:objects];
}

- (void)insertObject:(id)object atArrangedObjectIndex:(NSUInteger)index
{
	if (!skipFlag_) {
		[self _addObserverFor:[NSArray arrayWithObject:object]];
			//		NSLog(@"info: %@", [object observationInfo]);

		[[self.undoManager prepareWithInvocationTarget:self]
		 removeObjectAtArrangedObjectIndex:index];
		
			//	[[self.undoManager prepareWithInvocationTarget:self]
			//	 removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndex:index]];		
	}
	[super insertObject:object atArrangedObjectIndex:index];
}

- (void)insertObjects:(NSArray *)objects atArrangedObjectIndexes:(NSIndexSet *)indexes
{
	[self _addObserverFor:objects];

	[[self.undoManager prepareWithInvocationTarget:self]
	 removeObjectsAtArrangedObjectIndexes:indexes];

	skipFlag_ = YES;
	[super insertObjects:objects atArrangedObjectIndexes:indexes];
	skipFlag_ = NO;
}

- (void)removeObject:(id)object
{
	NSLog(@"%s|%@", __PRETTY_FUNCTION__, object);
}

- (void)removeObjects:(NSArray *)objects
{
	NSLog(@"%s|%@", __PRETTY_FUNCTION__, objects);	
}

- (void)removeObjectAtArrangedObjectIndex:(NSUInteger)index
{
	if (!skipFlag_) {
		
		NSArray* arrangedObjects = [self arrangedObjects];
		id object = [arrangedObjects objectAtIndex:index];

		[self _removeObserverFor:[NSArray arrayWithObject:object]];
		
		[[self.undoManager prepareWithInvocationTarget:self]
		 insertObject:object atArrangedObjectIndex:index];		
	}
	[super removeObjectAtArrangedObjectIndex:index];	
}


- (void)removeObjectsAtArrangedObjectIndexes:(NSIndexSet *)indexes
{
	NSArray* arrangedObjects = [self arrangedObjects];
	NSMutableArray* insertObjects = [NSMutableArray arrayWithCapacity:[indexes count]];
	
	[indexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		id object = [arrangedObjects objectAtIndex:idx];
			//		NSLog(@"info: %@", [object observationInfo]);
		[insertObjects addObject:object];
	}];
	
	[self _removeObserverFor:insertObjects];

	[[self.undoManager prepareWithInvocationTarget:self]
	 insertObjects:insertObjects atArrangedObjectIndexes:indexes];
	
	skipFlag_ = YES;
	[super removeObjectsAtArrangedObjectIndexes:indexes];
	skipFlag_ = NO;
}


#pragma mark -
#pragma mark Undo / Redo
-(BOOL)undo
{
	if ([self.undoManager canUndo]) {
		[self.undoManager undo];
		return YES;
	} else {
		return NO;
	}
}
-(BOOL)redo
{
	if ([self.undoManager canRedo]) {
		[self.undoManager redo];
		return YES;
	} else {
		return NO;
	}
}

-(IBAction)undo:(id)sender;
{
	[self undo];
}
-(IBAction)redo:(id)sender;
{
	[self redo];
}


	//----
#pragma mark -
#pragma mark Selection
- (void)_registSelectionToUndo
{
	[[self.undoManager prepareWithInvocationTarget:self]
	 setSelectionIndexes:[self selectionIndexes]];
	
}
- (BOOL)setSelectionIndex:(NSUInteger)index
{
	BOOL result = [super setSelectionIndex:index];
	if (result) {
		[self _registSelectionToUndo];		
	}
	return result;
}
- (BOOL)setSelectionIndexes:(NSIndexSet *)indexes
{
	BOOL result =  [super setSelectionIndexes:indexes];
	if (result) {
		[self _registSelectionToUndo];		
	}
	return result;
}
- (BOOL)setSelectedObjects:(NSArray *)objects
{
	BOOL result =  [super setSelectedObjects:objects];
	if (result) {
		[self _registSelectionToUndo];		
	}
	return result;
}
- (BOOL)addSelectedObjects:(NSArray *)objects
{
	BOOL result = [super addSelectedObjects:objects];
	if (result) {
		[self _registSelectionToUndo];		
	}
	return result;
}

- (void)selectPrevious:(id)sender
{
	if ([self canSelectPrevious]) {
		[self _registSelectionToUndo];
	}
	[super selectPrevious:sender];
}
- (void)selectNext:(id)sender
{
	if ([self canSelectNext]) {
		[self _registSelectionToUndo];
	}
	[super selectNext:sender];
}

#pragma mark -
#pragma mark Filtering Content
- (void)setSortDescriptors:(NSArray *)sortDescriptors
{
	NSLog(@"%s|%@", __PRETTY_FUNCTION__, sortDescriptors);
	[[self.undoManager prepareWithInvocationTarget:self]
	 setSortDescriptors:[self sortDescriptors]];
	[super setSortDescriptors:sortDescriptors];
}
/*
- (NSArray *)arrangeObjects:(NSArray *)objects
{
	NSLog(@"%s|%@", __PRETTY_FUNCTION__, objects);
	return objects;
}
- (void)setFilterPredicate:(NSPredicate *)filterPredicate
{
	NSLog(@"%s|%@", __PRETTY_FUNCTION__, filterPredicate);
}
- (void)didChangeArrangementCriteria
{
		//  [self filterPredicate] => Nil
	NSLog(@"%s|%@", __PRETTY_FUNCTION__,[self automaticRearrangementKeyPaths]);
}
 */
@end
