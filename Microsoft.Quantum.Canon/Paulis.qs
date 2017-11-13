// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

namespace Microsoft.Quantum.Canon {
    open Microsoft.Quantum.Primitive;

    /// <summary>
    ///     Measures the given Pauli operator using an explicit scratch
    ///     qubit to perform the measurement.
    /// </summary>
    /// <param name="pauli">
    ///     A multi-qubit Pauli operator specified as an array of
    ///     single-qubit Pauli operators.
    /// </param>
    /// <param name="target">Qubit register to be measured.</param>
    operation MeasureWithScratch(pauli : Pauli[], target : Qubit[])  : Result
    {
        body {
            mutable result = Zero;

            using (scratchRegister = Qubit[1]) {
                let scratch = scratchRegister[0];
                H(scratch);
                for (idxPauli in 0..(Length(pauli) - 1)) {
                    let P = pauli[idxPauli];
                    let src = target[idxPauli];

                    if (P == PauliX) {
                        (Controlled X)([scratch], src);
                    } elif (P == PauliY) {
                        (Controlled Y)([scratch], src);
                    } elif (P == PauliZ) {
                        (Controlled Z)([scratch], src);
                    }
                }
                H(scratch);
                set result = M(scratch);
            }

            return result;
        }
    }

    operation MeasureWithScratchTest() : () {
        body {
            using (register = Qubit[2]) {
                PrepareEntangledState([register[0]], [register[1]]);
                X(register[1]);

                let xxScratch = MeasureWithScratch([PauliX; PauliX], register);
                let xx = Measure([PauliX; PauliX], register);
                if (xx != xxScratch) {
                    fail "<XX>: MeasureWithScratch and Measure disagree";
                }

                let yyScratch = MeasureWithScratch([PauliY; PauliY], register);
                let yy = Measure([PauliY; PauliY], register);
                if (yy != yyScratch) {
                    fail "<yy>: MeasureWithScratch and Measure disagree";
                }

                let zzScratch = MeasureWithScratch([PauliZ; PauliZ], register);
                let zz = Measure([PauliZ; PauliZ], register);
                if (zz != zzScratch) {
                    fail "<ZZ>: MeasureWithScratch and Measure disagree";
                }
            }
        }
    }

    operation RandomSingleQubitPauli() : Pauli {
        body {
            let probs = [0.5; 0.5; 0.5; 0.5];
            let idxPauli = Random(probs);
            let singleQubitPaulis = [PauliI; PauliX; PauliY; PauliZ];
            return singleQubitPaulis[idxPauli];
        }
    }

    /// <summary>
    ///     Given a multi-qubit Pauli operator, applies the corresponding operation to
    ///     a register.
    /// </summary>
    /// <param name="pauli">A multi-qubit Pauli operator represented as an array of single-qubit Pauli operators.</param>
    /// <param name="target">Register to apply the given Pauli operation on.</param>
    operation ApplyPauli(pauli : Pauli[], target : Qubit[])  : ()
    {
        body {
            for (idxPauli in 0..(Length(pauli) - 1)) {
                let P = pauli[idxPauli];
                let targ = target[idxPauli];

                if (P == PauliX) {
                    X(targ);
                }
                elif (P == PauliY) {
                    Y(targ);
                }
                elif (P == PauliZ) {
                    Z(targ);
                }
            }
        }

        adjoint auto
        controlled auto
        adjoint controlled auto
    }   

    /// <summary>
    /// Applies a Pauli operator on the n^th qubit if the n^th bit of a Boolean array is true.
    /// </summary>
    /// <param name = "pauli"> Pauli to apply </param>
    /// <param name = "bitApply"> apply Pauli if bit is this value </param>
    /// <param name = "bits"> Boolean array </param>
    /// <param name = "qubits"> Quantum register </param>
    /// <remarks> 
    /// The boolean array and the quantum register must be of equal length.
    /// </remarks>
    operation ApplyPauliFromBitString(pauli : Pauli, bitApply: Bool, bits : Bool[], qubits : Qubit[]) : ()
    {
        body {
            let nBits = Length(bits);
            //FailOn (nbits != Length(qubits), "Number of control bits must be equal to number of control qubits")

            for (idxBit in 0..nBits - 1) {
                if (bits[idxBit] == bitApply) {
                    ApplyPauli([pauli], [qubits[idxBit]]);
                }
            }
        }
        adjoint auto
        controlled auto
        adjoint controlled auto
    }

    /// <summary>
    ///     Given an array of multi-qubit Pauli operators, measures each using a specified measurement
    ///     gadget, then returns the array of results.
    /// </summary>
    /// <param name="paulis">Array of multi-qubit Pauli operators to measure.</param>
    /// <param name="target">Register on which to measure the given operators.</param>
    /// <param name="gadget">Operation which performs the measurement of a given multi-qubit operator.</param>
    // FIXME: make qubit[] argument last.
    // FIXME: introduce MeasurementGadget UDT!!!
    operation MeasurePaulis(paulis : Pauli[][], target : Qubit[], gadget : ((Pauli[], Qubit[]) => Result))  : Result[]
    {
        body {
            mutable results = new Result[Length(paulis)];

            for (idxPauli in 0..(Length(paulis) - 1)) {
                set results[idxPauli] = gadget(paulis[idxPauli], target);
            }

            return results;
        }
    }

    /// <summary>
    ///     Given a single-qubit Pauli operator and the index of a qubit,
    ///     returns a multi-qubit Pauli operator with the given single-qubit
    ///     operator at that index and <c>IPauli</c> at every other index.
    /// </summary>
    /// <example>
    ///     To obtain the array <c>[PauliI; PauliI; PauliX; PauliI]</c>:
    ///     <c>
    ///         EmbedPauli(PauliX, 2, 3)
    ///     </c>
    /// </example>
    function EmbedPauli(pauli : Pauli, location : Int, n : Int)  : Pauli[]
    {
        mutable pauliArray = new Pauli[n];
        for (index in 0..(n-1)) {
            if (index == location) {
                set pauliArray[index] = pauli;
            }
            else {
                set pauliArray[index] = PauliI;
            }
        }
        return pauliArray;
    }

    /// summary:
    ///     Returns an array of all weight-1 Pauli operators
    ///     on a given number of qubits.
    // FIXME: Remove in favor of something that computes arbitrary
    //        weight Paulis.
    function WeightOnePaulis(nQubits : Int) : Pauli[][] {
        mutable paulis = new (Pauli[])[3 * nQubits];
        let pauliGroup = [PauliX; PauliY; PauliZ];

        for (idxQubit in 0..nQubits - 1) {
            for (idxPauli in 0..Length(pauliGroup) - 1) {
                set paulis[idxQubit * Length(pauliGroup) + idxPauli] = EmbedPauli(pauliGroup[idxPauli], idxQubit, nQubits);
            }
        }

        return paulis;
    }

    // NB: This operation is intended to be private to Paulis.qb.
    operation BasisChangeZtoY(target : Qubit) : () {
        body {
            H(target);
            S(target);
        }
        adjoint auto
        controlled auto
        controlled adjoint auto
    }

    // FIXME: these are currently redundant as heck.

    /// <summary>
    ///     Measures a single qubit in the Z basis and ensures that it
    ///     is in the |0> state following the measurement.
    /// </summary>
    operation MResetZ(target : Qubit) : Result {
        body {
            let result = M(target);
            if (result == One) {
                // Recall that the +1 eigenspace of a measurement operator corresponds to
                // the Result case Zero. Thus, if we see a One case, we must reset the state 
                // have +1 eigenvalue.
                X(target);
            }
            return result;
        }
    }

    /// <summary>
    ///     Measures a single qubit in the X basis and ensures that it
    ///     is in the |0> state following the measurement.
    /// </summary>
    operation MResetX(target : Qubit) : Result {
        body {
            let result = Measure([PauliX], [target]);
            // We must return the qubit to the Z basis as well.
            H(target);
            if (result == One) {
                // Recall that the +1 eigenspace of a measurement operator corresponds to
                // the Result case Zero. Thus, if we see a One case, we must reset the state 
                // have +1 eigenvalue.
                X(target);
            }
            return result;
        }
    }

    /// <summary>
    ///     Measures a single qubit in the X basis and ensures that it
    ///     is in the |0> state following the measurement.
    /// </summary>
    operation MResetY(target : Qubit) : Result {
        body {
            let result = Measure([PauliY], [target]);
            // We must return the qubit to the Z basis as well.
            
            (Adjoint BasisChangeZtoY)(target);
            if (result == One) {
                // Recall that the +1 eigenspace of a measurement operator corresponds to
                // the Result case Zero. Thus, if we see a One case, we must reset the state 
                // have +1 eigenvalue.
                X(target);
            }
            return result;
        }
    }

    /// <summary>
    ///     Given a single qubit, measures it and ensures it is in the |0> state
    ///     such that it can be safely released.
    /// </summary>
    operation Reset(target : Qubit) : () {
        body {
            let ignore = MResetZ(target);
            // Note that since operations cannot end with a let statement,
            // and since MResetZ returns a Result instead of (), we must do
            // *something* here. Thus, we do a nop.
            I(target);
        }
    }

    /// <summary>
    ///     Given an array of qubits, measure them and ensure they are in the |0> state
    ///     such that they can be safely released.
    /// </summary>
    operation ResetAll(target : Qubit[]) : () 
    {
        body {
            ApplyToEach(Reset, target);
        }
    }


}