class SortOption {
  const SortOption({
    required this.label,
    required this.path,
    required this.value,
  });

  final String label;
  final String path;
  final String value;

  static const all = [
    SortOption(label: '最新精选', path: '/video', value: 'mr'),
    SortOption(label: '最多次观看', path: '/video?o=mv', value: 'mv'),
    SortOption(label: '最高分', path: '/video?o=tr', value: 'tr'),
    SortOption(label: '最热门', path: '/video?o=ht', value: 'ht'),
    SortOption(label: '最长', path: '/video?o=lg', value: 'lg'),
    SortOption(label: '最新', path: '/video?o=cm', value: 'cm'),
  ];
}
