import sys

def generate_guess(input_data):
    # Generate all possible guesses
    universe = [(col, num) for col in range(1, 5) for num in range(10)]
    respectful_guesses = universe
    print(respectful_guesses)

    # Eliminate all guesses that contain grey numbers
    grey_numbers = {i[2] for i in input_data if i[1] == 'G'}
    respectful_guesses = [guess for guess in universe if guess[1] not in grey_numbers]
    print(respectful_guesses)

    # Eliminate all guesses that are not the blue number in a column
    for stat in [stat for stat in input_data if stat[1] == 'B']:
        # Remove all guesses for the column that was blue
        respectful_guesses = [g for g in respectful_guesses if g[0] != stat[0]]
        # Except leave the good one
        respectful_guesses.append((stat[0], stat[2]))
    print(respectful_guesses)

    # Eliminate all the guesses that have been yellow
    for stat in [stat for stat in input_data if stat[1] == 'Y']:
        respectful_guesses = [g for g in respectful_guesses if g != (stat[0], stat[2])]
    print(respectful_guesses)

    # Make a guess from the remaining guesses
    guess = list(range(5))
    for i in range(1, 5):
        for g in respectful_guesses:
            if g[0] == i:
                guess[i] = g[1]
    print(guess[1:5])


input_data = [line.strip().split(';') for line in sys.stdin]
input_data = [[int(data[0]), data[1], int(data[2])] for data in input_data]
generate_guess(input_data)
