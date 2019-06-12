### Concurrency

iOS 中一个应用进程可以有多个线程。操作系统管理每个线程，每个线程都**可以**并发地执行，但是操作系统决定是否会同时执行，什么时候，以及如何实现。

单核处理器设备通过 **time-slicing(时间片)** 实现，执行一个线程，执行上下文切换，再执行另一个线程。

多核处理器设备，通过 **parallelism(并行)** 同时执行多个线程。

<img width="50%" height="50%" src="assets/Concurrency_vs_Parallelism.png"/>

GCD 建立在线程之上，它维护着一个线程池。在 GCD 中通过代码块添加任务到 **dispatch queues** 然后 GCD 决定用哪个线程去执行它们。

GCD 根据系统和可用的系统资源来决定有多少个并行。

> 并行需要并发，但是并发并不保证并行

**并发并行的区别**

>concurrency is about *structure* while parallelism is about *execution*

### Queues

GCD 以 FIFO 的顺序执行添加进队列的任务，保证先添加进队列的任务比后添加进队列的任务先**开始**执行。

Dispatch queues 是线程安全的，可以多线程同时存取队列。

队列分为**串行**队列和**并发**队列。

串行队列保证在某一时刻只有一个任务在执行，GCD 控制执行时间，你不能确定在任务之间的间隔时间。

<img width="50%" height="50%" src="assets/Serial-Queue-Swift.png"/>

并发队列可以让多个任务在同一时间执行。任务开始执行的顺序还是遵守 FIFO 的规则，任务结束的顺序是不确定的，开始两个任务的时间间隔也是不确定的，同时执行的任务数量也是不确定的。

<img width="50%" height="50%" src="assets/Concurrent-Queue-Swift.png"/>

当两个任务的执行时间重叠时，GCD 会决定是否在多核上执行或者通过时间片的方式执行。

GCD 提供三种主要类型的队列：

1. **Main queue**：在主线程执行并且是一个串行队列
2. **Global queues**: 整个系统共享的并发队列，共有四个不同优先级的队列：`high, default, low, background` 。background 优先级的 queue 在 I/O 活动中被限制以减少对系统的负面影响。
3. **Custom queues**: 可以是串行或者并发队列，*这些队列中的请求最终会在一个全局队列中*

全局队列的优先级属性在 iOS8 上被废弃，替代的方式是使用 QoS。

1. **User-interactive**: 任务必须马上完成以提供一个好的用户体验。
2. **User-initiated**: 用户从UI操作开始这些异步操作。用于用户等待立即的结果和被用户交互依赖的任务。对应 `high` 优先级全局队列。
3. **Default**: 默认，QoS 参数省略时的默认值，对应 `default` 优先级全局队列。
4. **Utility**: 长时间运行的任务，典型的应用是用户可见的进度指示器。可用于计算、I/O、网络、持续数据流等。对应 `low` 优先级全局队列。
5. **Background**: 用户没有意识到的任务。可用于预加载、维护、其它的无用户交互的/非是时间敏感的任务。对应 `background` 优先级的全局队列。

### Synchronous vs. Asynchronous

同步方法在任务完成之后将控制返回给调用者。

异步方法立刻返回，保持任务开始的顺序，但是不会等待任务的结束。因此，异步方法不会阻塞当前的线程执行下一个方法。

### Managing Tasks

GCD 用闭包的方式添加任务，每个提交给 `DispatchQueue` 的任务都是一个 `DispatchWorkItem` 。

可以设置  `DispatchWorkItem` 的 `QoS` 或者是否产生新的线程等。