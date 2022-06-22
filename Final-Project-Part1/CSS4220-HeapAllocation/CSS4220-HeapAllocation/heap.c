/*
 * This is a C implementation of malloc( ) and free( ), based on the buddy
 * memory allocation algorithm.
 */
#include <stdio.h> // printf

/*
 * The following global variables are used to simulate memory allocation
 * Cortex-M's SRAM space.
 */
// Heap
char array[0x8000];            // simulate SRAM: 0x2000.0000 - 0x2000.7FFF
int heap_top   = 0x20001000;   // the top of heap space
int heap_bot   = 0x20004FE0;   // the address of the last 32B in heap
int max_size   = 0x00004000;   // maximum allocation: 16KB = 2^14
int min_size   = 0x00000020;   // minimum allocation: 32B = 2^5

// Memory Control Block: 2^10B = 1KB space
int mcb_top    = 0x20006800;   // the top of MCB
int mcb_bot    = 0x20006BFE;   // the address of the last MCB entry
int mcb_ent_sz = 0x00000002;   // 2B per MCB entry
int mcb_total  = 512;          // # MCB entries: 2^9 = 512 entries

/*
 * Convert a Cortex SRAM address to the corresponding array index.
 * @param  sram_addr address of Cortex-M's SRAM space starting at 0x20000000.
 * @return array index.
 */
int m2a( int sram_addr ) {
  int index = sram_addr - 0x20000000;
  // printf( "m2a: sram_addr = %x array_index = %d\n", sram_addr, index );
  return index;
}

/*
 * Reverse an array index back to the corresponding Cortex SRAM address.
 * @param  array index.
 * @return the corresponding Cortex-M's SRAM address in an integer.
 */
int a2m( int array_index ) {
  return array_index + 0x20000000;
}

/*
 * In case if you want to print out, all array elements that correspond
 * to MCB: 0x2006800 - 0x20006C00.
 */
void printArray( ) {
  printf( "memroy ............................\n" );
  for ( int i = 0; i < 0x8000; i+=4 )
    if ( a2m( i ) >= 0x20006800 )
     printf( "%x = %x(%d)\n",
         a2m( i ), *(int *)&array[i], *(int *)&array[i] );
}

/*
 * _ralloc is _kalloc's helper function that is recursively called to
 * allocate a requested space, using the buddy memory allocaiton algorithm.
 * Implement it by yourself in step 1.
 *
 * @param  size  the size of a requested memory space
 * @param  left_mcb_addr  the address of the left boundary of MCB entries to examine
 * @param  right_mcb_addr the address of the right boundary of MCB entries to examine
 * @return the address of Cortex-M's SRAM space. While the computation is
 *         made in integers, cast it to (void *). The gcc compiler gives
 *         a warning sign:
                cast to 'void *' from smaller integer type 'int'
 *         Simply ignore it.
 */
void *_ralloc( int size, int left_mcb_addr, int right_mcb_addr ) {
  // printf( "_ralloc: size=%d, left_mcb_addr=%x, right_mcb_addr=%x\n", size, left_mcb_addr, right_mcb_addr );
  // initial parameter computation
  int entire_mcb_addr_space = right_mcb_addr - left_mcb_addr  + mcb_ent_sz;
  int half_mcb_addr_space = entire_mcb_addr_space / 2;
  int midpoint_mcb_addr = left_mcb_addr + half_mcb_addr_space;
  int heap_addr = 0; // null
  int act_entire_heap_size = entire_mcb_addr_space * 16;
  int act_half_heap_size = half_mcb_addr_space * 16;

  // printf( "entire_mcb_addr_space=%d, half_mcb_addr_space=%d, midpoint_mcb_addr=%x, heap_addr=%x, act_entire_heap_size=%d, act_half_heap_size=%d\n",
  //      entire_mcb_addr_space, half_mcb_addr_space, midpoint_mcb_addr, heap_addr, act_entire_heap_size, act_half_heap_size );

  // base case
  if ( size <= act_half_heap_size ) { // branchM1
    // _ralloc_left
    // printf( "_ralloc_left\n" );
    // allocate from the left half
    void* heap_addr = _ralloc( size, left_mcb_addr, midpoint_mcb_addr - mcb_ent_sz );
    if ( heap_addr == 0 ) { // branchM11
      // __alloc_right
      // printf( "_ralloc_right\n" );
      // there is no space in the left half, allocate from the right half
      return _ralloc( size, midpoint_mcb_addr, right_mcb_addr );
    }
    // if reaching here, allocation happens to the right
    // so we need to split the parent MCB
    // if the allocaiton happends to the left, no
    if ( ( array[ m2a( midpoint_mcb_addr ) ] & 0x01 ) == 0 )
      *(short *)&array[ m2a( midpoint_mcb_addr ) ] = act_half_heap_size;
    return heap_addr;
  }
  else { // branchM2
    // needs to occupy this whole chunk because the size is greater than half
    if ( ( array[ m2a( left_mcb_addr ) ] & 0x01 ) != 0 ) {
      // used!
      return 0; // return invalid
    }
    else { // branchM21
      // yes, we have an entire space
      if ( *(short *)&array[ m2a( left_mcb_addr ) ] < act_entire_heap_size )
        // can't fit
        return 0;
        // set the MCB's value, including both size and in-use bit
      *(short *)&array[ m2a( left_mcb_addr ) ] = act_entire_heap_size | 0x01;

      // compute the corresponding heap address
        void* retVal = (void *)( heap_top + ( left_mcb_addr - mcb_top ) * 16 );
        return retVal; //(void *)( heap_top + ( left_mcb_addr - mcb_top ) * 16 );
    }
  }
  return 0;
}

/*
 * _rfree is _kfree's helper function that is recursively called to
 * deallocate a space, using the buddy memory allocaiton algorithm.
 * Implement it by yourself in step 1.
 *
 * @param  mcb_addr that corresponds to a SRAM space to deallocate
 * @return the same as the mcb_addr argument in success, otherwise 0.
 */
int _rfree( int mcb_addr ) {
  // printf( "_rfree( %x ): mcb[%x] = %x (%d in dec)\n", mcb_addr,
  //       mcb_addr, *(short *)&array[ m2a( mcb_addr ) ],
  //      *(short *)&array[ m2a( mcb_addr ) ] );
  
  short mcb_contents = *(short *)&array[ m2a( mcb_addr ) ];
  int mcb_index = mcb_addr - mcb_top;
  int mcb_disp = ( mcb_contents /= 16 );
  int my_size = ( mcb_contents *= 16 ); // clear the used bit

  // mcb_addr's used bit was cleared
  *(short *)&array[ m2a( mcb_addr ) ] = mcb_contents;

  // printf( "_rfree: mcb[%x] was updated to %x (%d in dec)\n", mcb_addr,
  //       mcb_addr, *(short *)&array[ m2a( mcb_addr ) ],
  //      *(short *)&array[ m2a( mcb_addr ) ] );
  
  // check if mcb_index is left (==0) or right (==1)

  // printf( "_rfree: mcb_index = %d, mcb_disp = %d\n", mcb_index, mcb_disp );
  
  if ( ( mcb_index / mcb_disp ) % 2 == 0 ) {                                    // branchF1
    // I'm left
    // printf( "_rfree: left\n" );
    
    if ( mcb_addr + mcb_disp >= mcb_bot )
      return 0; // my buddy is beyond mcb_bot!
    else {                                                                      // branchF11
      short mcb_buddy = *(short *)&array[ m2a( mcb_addr + mcb_disp ) ];

      // printf( "_rfree: mcb_buddy's address: %x, contents = %x(%d)\n",
      //          ( mcb_addr + mcb_disp ), mcb_buddy, mcb_buddy );
      
      if ( ( mcb_buddy & 0x0001 ) == 0 ) {                                      // branchF111
    // my buddy is not used
    // printf( "my buddy is not used\n" );
    
        mcb_buddy = ( mcb_buddy / 32 ) * 32; // clear bit 4-0
        if ( mcb_buddy == my_size ) {                                           // branchF1111

      // printf( "_rfree: mcb_budy == my_size = %d\n", mcb_buddy );
      
      // my buddy is unused and has the same size.
          *(short *)&array[ m2a( mcb_addr + mcb_disp ) ] = 0; // clear my buddy
          my_size *= 2;
          *(short *)&array[ m2a( mcb_addr ) ] = my_size; // merge my budyy

      // printf( "_rfree: my_buddy cleared = %d, myself = %d\n",
      //      *(short *)&array[ m2a( mcb_addr + mcb_disp ) ],
      //      *(short *)&array[ m2a( mcb_addr ) ] );
      // printf( "_rfree: promoto myself\n" );

      // promote myself
          return _rfree( mcb_addr );
        }
      }
    }
  }
  else {                                                                          // branchF2
    // I'm right
    // printf( "_rfree: right\n" );
    
    if ( mcb_addr - mcb_disp < mcb_top )
      return 0; // my buddy is below mcb_top!
    else {                                                                        // branchF21
      short mcb_buddy = *(short *)&array[ m2a( mcb_addr - mcb_disp ) ];

      // printf( "_rfree: mcb_buddy's address: %x, contents = %x(%d)\n",
      //     ( mcb_addr - mcb_disp ), mcb_buddy, mcb_buddy );
      
      if ( ( mcb_buddy & 0x0001 ) == 0 ) {                                          // branchF211
    // my buddy is not used
    // printf( "my buddy is not used\n" );
    
        mcb_buddy = ( mcb_buddy / 32 ) * 32; // clear bit 4-0
        if ( mcb_buddy == my_size ) {                                               // branchF2111

      // printf( "_rfree: mcb_budy == my_size = %d\n", mcb_buddy );
      
      // my buddy is unused and has the same size.
          *(short *)&array[ m2a( mcb_addr ) ] = 0; // clear myself
          my_size *= 2;
          *(short *)&array[ m2a( mcb_addr - mcb_disp ) ] = my_size; // merge me to my buddy

      // printf( "_rfree: myself cleared = %d, my buddy = %d\n",
      //      *(short *)&array[ m2a( mcb_addr ) ],
      //      *(short *)&array[ m2a( mcb_addr - mcb_disp ) ] );
      // printf( "_rfree: promoto my buddy\n" );

      // promote my buddy
          return _rfree( mcb_addr - mcb_disp );
        }
      }
    }
  }
  
  return mcb_addr;
}

/*
 * Initializes MCB entries. In step 2's assembly coding, this routine must
 * be called from Reset_Handler in startup_TM4C129.s before you invoke
 * driver.c's main( ).
 */
void _kinit( ) {
  // Zeroing the heap space: no need to implement in step 2's assembly code.
  for ( int i = 0x20001000; i < 0x20005000; i++ )
    array[ m2a( i ) ] = 0;

  // Initializing MCB: you need to implement in step 2's assembly code.
  *(short *)&array[ m2a( mcb_top ) ] = max_size;
    
  for ( int i = 0x20006804; i < 0x20006C00; i += 2 ) {
    array[ m2a( i ) ] = 0;
    array[ m2a( i + 1) ] = 0;
  }
}

/*
 * Step 2 should call _kalloc from SVC_Handler.
 *
 * @param  the size of a requested memory space
 * @return a pointer to the allocated space
 */
void *_kalloc( int size ) {
  // printf( "_kalloc called\n" );
  return _ralloc( size, mcb_top, mcb_bot );
}

/*
 * Step 2 should call _kfree from SVC_Handler.
 *
 * @param  a pointer to the memory space to be deallocated.
 * @return the address of this deallocated space.
 */
void *_kfree( void *ptr ) {
  int addr = (int )ptr;

  // validate the address
  // printf( "\n_kfree( %x )\n", ptr );
  if ( addr < heap_top || addr > heap_bot )
    return NULL;

  // compute the mcb address corresponding to the addr to be deleted
  int mcb_addr =  mcb_top + ( addr - heap_top ) / 16;
  
  if ( _rfree( mcb_addr ) == 0 )
    return NULL;
  else
    return ptr;
}

/*
 * _malloc should be implemented in stdlib.s in step 2.
 * _kalloc must be invoked through SVC in step 2.
 *
 * @param  the size of a requested memory space
 * @return a pointer to the allocated space
 */
void *_malloc( int size ) {
  static int init = 0;
  if ( init == 0 ) {
    init = 1;
    _kinit( ); // In step 2, you will call _kinit from Reset_Handler
  }
  return _kalloc( size );
}

/*
 * _free should be implemented in stdlib.s in step 2.
 * _kfree must be invoked through SVC in step 2.
 *
 * @param  a pointer to the memory space to be deallocated.
 * @return the address of this deallocated space.
 */
void *_free( void *ptr ) {
  return _kfree( ptr );
}
