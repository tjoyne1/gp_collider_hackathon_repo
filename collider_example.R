# What's going on with the weather in Asheville, NC this weekend?
# When I arrived the high temperature was 72degF, but this forecast
# low temperature tomorrow is 25degF.  That seems like a big
# change, but I'm not from around these parts, so let's look at the data.

# First, we will load a few libraries:
library(taRpan)
library(ggplot2)
library(dplyr)
library(fitdistrplus)
library(rgeos)
library(glue)

# Alright, our database consists of 1600 cities with population >250k... 
# so not Asheville.  Let's download the project_tbl and look at the data:
geography_db <- tarpan2_get_table(con = 'collider_heat_stress',
                                  table_name = 'project_tbl')
asheville <- 'SRID=4326;POINT(-82.553570 35.595019)'

tarpan2_query(con = 'collider_heat_stress',
              query = glue("SELECT fname,",
                           "ST_Distance(ST_GeomFromEWKT('{asheville}'),the_geom) ",
                           "as dist ",
                           "FROM project_tbl order by dist asc limit 5"))

# Next, let's grab the max and min daily temperatures from the server
# for Charlotte, which is the closest location in our database:
geography <- ''
model <- 'cfs2_hindcast'
bias_correction <- ''

max_temp <- tarpan_model_data(dbname = 'collider_heat_stress',
                              geography = geography,
                              variable = 'max_temperature_gmtday',
                              model = model, bc_method = bias_correction)

min_temp <- tarpan_model_data(dbname = 'collider_heat_stress',
                              geography = geography,
                              variable = 'min_temperature_gmtday',
                              model = model, bc_method = bias_correction)

# Hmm, that took a few seconds, how big are these data tables?
summary(max_temp)
summary(min_temp)

# OK, about 15k rows with daily data between 1979-01-01 and 2019-03-14,
# I suppose that is a lot of data.  Those values look like
# Kelvin and that hurts my brain, lets convert to Fahrenheit:
k_to_f <- function(k){(k-273.15)*9/5+32}
max_temp$val <- k_to_f(max_temp$val)
min_temp$val <- k_to_f(min_temp$val)

# Our database doesn't care about date order, so let's make sure the
# datasets have the same temporal order:
max_temp <- max_temp[order(max_temp$initial_time),]
min_temp <- min_temp[order(min_temp$initial_time),]

# We might pull in forecast data here, so let's filter down our results to
# only days when valid_time == initial_time
max_temp <- max_temp %>%
  filter(valid_time == initial_time)

min_temp <- min_temp %>%
  filter(valid_time == initial_time)

# Let's also make it one dataframe, add a categorical variable column,
# and then see what it looks like
data <- data.frame(max_temp,var = "max_temp")
data <- rbind(data,data.frame(min_temp,var = "min_temp"))

ggplot(data = data,
       aes(x = initial_time, y = val, group = var, col = var)) +
  geom_line(size=0.25) +
  xlab("Date") +
  ylab("Daily Variable (degF)") +
  ggtitle(paste(model,"results for",geography))

# yup, that's temperature data alright, but something weird is going on
# with this model at 2017, let's filter it to just look at data
# prior to 2017
data <- data %>%
  filter(initial_time < '2017-01-01')

# also, that's too much data, let's take a close look at some more recent data
data_recent <- data %>%
  filter(initial_time > '2015-01-01')

ggplot(data = data_recent,
       aes(x = initial_time, y = val, group = var, col = var)) +
  geom_line(size=0.25) +
  xlab("Date") +
  ylab("Daily Variable (degF)") +
  ggtitle(paste(model,"results for",geography))

# Now that we know how to access the data, let's get back to my original
# posit that it is unusual that the high temperate is 72degF today and
# low temp is 25 degF tomorrow, a temperature delta of 47degF!
# Let's create a new dataframe with the temperature delta:
delta_temp_today <- 72 - 25

# we need to offset by a day to be strictly correct in our comparison
delta_temp <- head(max_temp,n = -1)
delta_temp$val <- delta_temp$val - tail(min_temp$val, n = -1)

delta_temp <- delta_temp %>%
  filter(initial_time < '2017-01-01')

ggplot(data = delta_temp,
       aes(x = initial_time, y = val)) +
  geom_line(size=0.25, col = "green") +
  xlab("Date") +
  ylab("Daily Temperature Delta (degF)") +
  ggtitle(paste(model,"results for",geography)) +
  geom_hline(aes(yintercept = delta_temp_today),
             linetype = 2,
             color = 'red')

# Wow, this is acutally unusual!  We're in uncharted territory, the last
# temperature swing of this magnitude occurred 1979-01-02 with a
# delta of 46.9degF

# Let's see how unlikely it is by creating an empirical cumulative density
# function (ecdf) using the historical delta and evaluating our t

delta_prob <- ecdf(delta_temp$val)
delta_temp_range <- seq(-5,50)
cdf <- ggplot() +
  xlab("x [Delta Temperature (degF)]") +
  ylab("1-Probability [X > x]") +
  ggtitle(paste("Delta Temp. Probability of Exceedance for",geography)) +
  geom_vline(aes(xintercept = delta_temp_today),
             linetype = 2,
             color = 'red') +
  geom_point(aes(x = x,
                 y = y),
             shape = 21,
             colour = "darkgrey",
             size = 3,
             stroke = 0.1,
             data = data.frame(x = delta_temp$val,
                               y = delta_prob(delta_temp$val))) +
  geom_line(aes(x = x, y = y),color = 'blue',
            data.frame(x = delta_temp_range,
                       y = delta_prob(delta_temp_range)))

plot(cdf)

1-delta_prob(delta_temp_today)

# Well that's that, we're setting a new baseball-stats-type record (you can
# make a record for anything!) The answer using the ecdf implies that there
# is 0% probability that a temperature delta equal to or greater than 47deg
# will occur.  But this model was built with only 38 years of data, so maybe
# we just missed something.  Let's instead use probabilistic model to help
# us think about how big of a difference we *could* see.

fit <-  fitdist(delta_temp$val,'norm')
plot(fit)

# It looks like a normal distribution fit's our data well enough, let's
# compare to our last plot:

cdf_comp <- cdf +
  geom_line(aes(x = x, y = y),color = 'green',
            data.frame(x = delta_temp_range,
                       y = pnorm(delta_temp_range,
                                 fit$estimate[[1]],
                                 fit$estimate[[2]])))
plot(cdf_comp)

# and finally, let's evaluate the average number of years we would expect
# to pass before seeing some extreme values.  This is also known as the
# return period (rp) and is an important concept in extreme event analysis:
extreme_delta_temp <- seq(40,60,0.1)
compare <- data.frame(delta_temp = extreme_delta_temp,
                      ecdf_rp = (1/(1-delta_prob(extreme_delta_temp)))/365.25,
                      ncdf_rp = (1/(1-pnorm(extreme_delta_temp,
                                     fit$estimate[[1]],
                                     fit$estimate[[2]])))/365.25)

ggplot(data = compare) +
  geom_line(aes(x = ecdf_rp, y = delta_temp),color = 'blue') +
  geom_line(aes(x = ncdf_rp, y = delta_temp),color = 'green') +
  scale_x_log10(limits = c(0.01,10000)) +
  xlab("Return Period (years)") +
  ylab("Delta Temperature (degF)") +
  ggtitle(paste("Delta Temp. Return Periods for",geography))

View(compare)
