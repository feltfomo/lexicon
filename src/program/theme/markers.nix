# identity lambdas on their own lines, so evaluator call counts and profiler
# frames can name a stage. each is applied once per stage entry, never per element
{
  composeThemes = value: value;
}
